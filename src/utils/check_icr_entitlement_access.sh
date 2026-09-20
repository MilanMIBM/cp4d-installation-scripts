#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" >&2 || echo "[TIMER] $(basename $0) completed in ${SECONDS}s" >&2' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; REPO_ROOT="${_b}"; source "${_b}/env_bootstrap.sh"; unset _b

# ---

usage() {
    cat <<'EOF'
Report what the icr.io credentials in pull-secret.dockerconfigjson can actually
pull, as a high-level overview.

  check_icr_entitlement_access.sh [options] [repository ...]

How this works, and what it can and cannot tell you:
  IBM Container Registry does NOT allow listing a catalog with an entitlement
  key: a token scoped to 'registry:catalog:*' is refused outright. There is
  therefore no way to ask the registry "what do I have access to?" and get an
  enumeration back. What the registry will do is answer, per repository,
  whether this credential may pull it. So this script probes a list of
  repositories and reports the verdict for each. The overview is only ever as
  complete as the list it is given.

  Note also that the token endpoint hands out a 'pull' grant for any repository
  name you ask about, including names that do not exist, so the token itself
  proves nothing. Only the registry's answer to a real tags/list request is
  authoritative, and this script relies on that answer.

Where the repository list comes from (first match wins):
  1. Repositories named as positional arguments.
  2. --from-csv FILE: a cpd-cli 'list_images.csv' export.
  3. --components: the component list from ./cpd_vars.sh, resolved to real
     repositories by running 'cpd-cli manage list-images'. This is the only
     source that is authoritative about which images a release actually uses.
     It needs a working cpd-cli container runtime (Podman), so it is not the
     default.
  4. Otherwise: a small built-in set of well-known CPD repositories, enough to
     answer "does this key work at all, and against which registries".

Verdicts:
  ENTITLED      the registry served the tag list; this credential can pull it
  NO ACCESS     the registry refused; the key is not entitled to this repository
  NOT FOUND     authorized, but no such repository on that host (usually the
                wrong host/path, not an entitlement problem)
  AUTH FAILED   the registry refused the credential; the key is bad or expired
  UNREACHABLE   the registry was never reached (TLS or network); this says
                nothing about the key. A TLS failure here is usually a python3
                with no CA store rather than anything to do with the registry.

Options:
  -f, --file PATH        Pull secret to read
                         (default: ./cp4d_config/pull-secret.dockerconfigjson,
                         else PULL_SECRET_FILE)
  -r, --registry HOST    Only probe this registry host (repeatable). Default is
                         every icr.io host found in the secret.
      --components       Resolve repositories via 'cpd-cli manage list-images'
      --from-csv FILE    Read repositories from a cpd-cli list_images.csv
      --release VERSION  Release for --components (default: VERSION from
                         cpd_vars.sh)
      --component-list L Comma-separated components for --components
                         (default: COMPLETE_COMPONENT_LIST)
      --tags [N]         List tags for each entitled repository, newest last
                         (default 5). '--tags 20' shows the newest 20.
      --all-tags         List every tag, however many there are
      --tag-arch ARCH    Only tags for this architecture (amd64, x86_64,
                         ppc64le, s390x, arm64), or 'none' for tags that pin
                         no architecture
      --tag-grep REGEX   Only tags matching this regular expression
  -q, --quiet            Only list entitled repositories
  -j, --json             Emit JSON instead of a table
  -h, --help             Show this help
EOF
}

PULL_SECRET_FILE_ARG=""
REGISTRIES=()
REPOS=()
USE_COMPONENTS=false
FROM_CSV=""
RELEASE="${VERSION:-}"
COMPONENT_LIST="${COMPLETE_COMPONENT_LIST:-}"
SHOW_TAGS=false
TAG_COUNT=5
TAG_ARCH=""
TAG_GREP=""
QUIET=false
AS_JSON=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)          PULL_SECRET_FILE_ARG="${2:-}"; shift 2 ;;
        -r|--registry)      REGISTRIES+=("${2:-}"); shift 2 ;;
        --components)       USE_COMPONENTS=true; shift ;;
        --from-csv)         FROM_CSV="${2:-}"; shift 2 ;;
        --release)          RELEASE="${2:-}"; shift 2 ;;
        --component-list)   COMPONENT_LIST="${2:-}"; shift 2 ;;
        --tags)
            SHOW_TAGS=true
            # Optional count: '--tags 20', but not '--tags cp.icr.io/...'.
            if [[ -n "${2:-}" && "${2}" == <-> ]]; then TAG_COUNT="${2}"; shift; fi
            shift ;;
        --all-tags)         SHOW_TAGS=true; TAG_COUNT=0; shift ;;
        --tag-arch)         SHOW_TAGS=true; TAG_ARCH="${2:-}"; shift 2 ;;
        --tag-grep)         SHOW_TAGS=true; TAG_GREP="${2:-}"; shift 2 ;;
        -q|--quiet)         QUIET=true; shift ;;
        -j|--json)          AS_JSON=true; shift ;;
        -h|--help)          usage; exit 0 ;;
        -*)                 echo "[ERROR] Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)                  REPOS+=("$1"); shift ;;
    esac
done

# --- Locate the pull secret --------------------------------------------------
if [[ -n "${PULL_SECRET_FILE_ARG}" ]]; then
    PULL_SECRET_FILE="${PULL_SECRET_FILE_ARG}"
else
    PULL_SECRET_FILE="${PULL_SECRET_FILE:-${REPO_ROOT}/cp4d_config/pull-secret.dockerconfigjson}"
fi

if [[ ! -f "${PULL_SECRET_FILE}" ]]; then
    echo "[ERROR] Pull secret not found: ${PULL_SECRET_FILE}" >&2
    echo "[ERROR] Run 1.0_set_up_global_pull_credential.sh first, or pass -f/--file." >&2
    exit 1
fi

# --- Build the repository list -----------------------------------------------
if (( ${#REPOS[@]} == 0 )) && [[ -n "${FROM_CSV}" ]]; then
    if [[ ! -f "${FROM_CSV}" ]]; then
        echo "[ERROR] CSV not found: ${FROM_CSV}" >&2
        exit 1
    fi
    echo "[INFO] Reading repositories from ${FROM_CSV}" >&2
    # list_images.csv carries fully qualified references; reduce each to the
    # repository path and drop the digest/tag so it can be probed directly.
    REPOS=("${(@f)$(CSV_PATH="${FROM_CSV}" python3 <<'PY'
import csv, os, re, sys

seen, out = set(), []
with open(os.environ["CSV_PATH"], newline="") as fh:
    for row in csv.reader(fh):
        for cell in row:
            cell = cell.strip()
            m = re.search(r"((?:[a-z0-9.-]+\.)?icr\.io)/([a-z0-9._/-]+)", cell)
            if not m:
                continue
            repo = m.group(2).split("@")[0]
            repo = re.sub(r":[A-Za-z0-9._-]+$", "", repo)
            key = f"{m.group(1)}/{repo}"
            if key not in seen:
                seen.add(key)
                out.append(key)
print("\n".join(out))
PY
)}")
fi

if (( ${#REPOS[@]} == 0 )) && [[ "${USE_COMPONENTS}" == true ]]; then
    if ! command -v cpd-cli >/dev/null 2>&1; then
        echo "[ERROR] --components needs cpd-cli on PATH." >&2
        exit 1
    fi
    if [[ -z "${RELEASE}" ]]; then
        echo "[ERROR] --components needs a release; set VERSION in ./cpd_vars.sh or pass --release." >&2
        exit 1
    fi
    if [[ -z "${COMPONENT_LIST}" ]]; then
        echo "[ERROR] --components needs a component list; set COMPLETE_COMPONENT_LIST or pass --component-list." >&2
        exit 1
    fi
    echo "[INFO] Resolving images for release ${RELEASE}, components: ${COMPONENT_LIST}" >&2
    echo "[INFO] This runs 'cpd-cli manage list-images' and needs a running container runtime; it can take a while." >&2
    _work="$(mktemp -d)"
    if ! ( cd "${_work}" && cpd-cli manage list-images \
              --release="${RELEASE}" \
              --components="${COMPONENT_LIST}" \
              --case_download=true >/dev/null 2>&1 ); then
        echo "[ERROR] 'cpd-cli manage list-images' failed. Is Podman running?" >&2
        echo "[ERROR] Run it yourself and pass the result with --from-csv list_images.csv." >&2
        rm -rf "${_work}"
        exit 1
    fi
    _csv="$(find "${_work}" -name 'list_images.csv' -print -quit)"
    if [[ -z "${_csv}" ]]; then
        echo "[ERROR] list-images produced no list_images.csv under ${_work}." >&2
        rm -rf "${_work}"
        exit 1
    fi
    REPOS=("${(@f)$(CSV_PATH="${_csv}" python3 <<'PY'
import csv, os, re

seen, out = set(), []
with open(os.environ["CSV_PATH"], newline="") as fh:
    for row in csv.reader(fh):
        for cell in row:
            cell = cell.strip()
            m = re.search(r"((?:[a-z0-9.-]+\.)?icr\.io)/([a-z0-9._/-]+)", cell)
            if not m:
                continue
            repo = m.group(2).split("@")[0]
            repo = re.sub(r":[A-Za-z0-9._-]+$", "", repo)
            key = f"{m.group(1)}/{repo}"
            if key not in seen:
                seen.add(key)
                out.append(key)
print("\n".join(out))
PY
)}")
    rm -rf "${_work}"
fi

if (( ${#REPOS[@]} == 0 )); then
    # Fallback probe set. These are deliberately few and well known: the point
    # is to establish whether the credential works and against which hosts,
    # not to pretend to be an inventory.
    REPOS=(
        cp.icr.io/cp/cpd/zen-core
        cp.icr.io/cp/cpd/zen-core-api
        cp.icr.io/cp/cpd/zen-watchdog
        icr.io/cpopen/cpd/olm-utils-v4
        icr.io/cpopen/cpd/olm-utils-v3
    )
    echo "[INFO] No repository list given; probing a built-in set of well-known CPD repositories." >&2
    echo "[INFO] Use --components or --from-csv for a list that reflects your actual release." >&2
fi

REPOS=("${(@u)REPOS}")

# --- Probe -------------------------------------------------------------------
# One python pass does the whole job: it reads the secret, works out the host
# for each repository, fetches a scoped token and asks the registry for tags.
# Keeping it in a single quoted heredoc with values passed through the
# environment avoids quoting the credential into the program text.
PULL_SECRET_FILE="${PULL_SECRET_FILE}" \
PROBE_REPOS="$(printf '%s\n' "${REPOS[@]}")" \
ONLY_REGISTRIES="$(printf '%s\n' "${REGISTRIES[@]}")" \
SHOW_TAGS="${SHOW_TAGS}" TAG_COUNT="${TAG_COUNT}" \
TAG_ARCH="${TAG_ARCH}" TAG_GREP="${TAG_GREP}" \
QUIET="${QUIET}" AS_JSON="${AS_JSON}" \
python3 <<'PY'
import base64, json, os, re, ssl, sys, urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

# Some python builds (notably the python.org installer, if its bundled
# "Install Certificates.command" was never run) ship with no CA store at all:
# ssl.get_default_verify_paths() returns cafile=None and every HTTPS call dies
# with CERTIFICATE_VERIFY_FAILED. Fall back to certifi, and failing that to the
# system bundle macOS keeps at /etc/ssl/cert.pem, so the check does not depend
# on which python3 happens to be first on PATH.
def _ssl_context():
    try:
        paths = ssl.get_default_verify_paths()
        if paths.cafile or paths.capath:
            return ssl.create_default_context()
    except Exception:
        pass
    for candidate in (_certifi_path(), "/etc/ssl/cert.pem"):
        if candidate and os.path.exists(candidate):
            try:
                return ssl.create_default_context(cafile=candidate)
            except Exception:
                continue
    return ssl.create_default_context()


def _certifi_path():
    try:
        import certifi
        return certifi.where()
    except Exception:
        return None


SSL_CTX = _ssl_context()

secret_path = os.environ["PULL_SECRET_FILE"]
show_tags = os.environ.get("SHOW_TAGS") == "true"
tag_count = int(os.environ.get("TAG_COUNT") or 5)
want_arch = (os.environ.get("TAG_ARCH") or "").strip().lower()
want_grep = os.environ.get("TAG_GREP") or ""
quiet = os.environ.get("QUIET") == "true"
as_json = os.environ.get("AS_JSON") == "true"

only = [r for r in os.environ.get("ONLY_REGISTRIES", "").split("\n") if r.strip()]
repos = [r.strip() for r in os.environ.get("PROBE_REPOS", "").split("\n") if r.strip()]

with open(secret_path) as fh:
    auths = json.load(fh).get("auths", {})

# Only the icr.io family is in scope here; the same secret usually also carries
# quay.io and registry.redhat.io, which are not IBM entitlement registries.
creds = {}
for host, entry in auths.items():
    if "icr.io" not in host:
        continue
    raw = entry.get("auth")
    if raw:
        try:
            user, _, password = base64.b64decode(raw).decode().partition(":")
        except Exception:
            continue
    else:
        user, password = entry.get("username", ""), entry.get("password", "")
    if user and password:
        creds[host] = (user, password)

if not creds:
    print(f"[ERROR] No icr.io credentials found in {secret_path}", file=sys.stderr)
    sys.exit(1)


def tag_sort_key(tag):
    """Order tags by version, newest last.

    A plain string sort is wrong for these registries: 'v3.0.1' sorts above
    '3.5.2' because 'v' follows the digits, and '-9' beats '-45' because the
    comparison is textual. Split into numeric and non-numeric runs instead so
    the numbers compare as numbers. Floating tags ('latest', 'stable') carry no
    version at all, so they sort first rather than masquerading as newest.
    """
    base = tag.lower()
    floating = base.split(".")[0] in ("latest", "stable", "main", "master", "edge")
    parts = []
    for chunk in re.findall(r"\d+|\D+", base):
        if chunk.isdigit():
            parts.append((1, int(chunk), ""))
        else:
            # 'v' is a bare version prefix, not a distinguishing token.
            cleaned = chunk.strip(".-_")
            if cleaned == "v":
                continue
            parts.append((0, 0, cleaned))
    return (0 if floating else 1, parts, tag)


ARCH_SUFFIXES = ("amd64", "x86_64", "ppc64le", "s390x", "arm64")


def tag_arch(tag):
    """Return the architecture a tag pins, if any.

    Matching cannot simply split on separators: 'x86_64' contains the very
    underscore that would be split on, so '4.1.1-x86_64-12' would lose its
    architecture. Match the names directly, bounded by a separator or the ends
    of the tag, longest first so 'x86_64' wins before a shorter name can.
    """
    low = tag.lower()
    for arch in sorted(ARCH_SUFFIXES, key=len, reverse=True):
        if re.search(rf"(?:^|[.\-_]){re.escape(arch)}(?:$|[.\-_])", low):
            return arch
    return None


def filter_tags(tags, arch, pattern):
    out = tags
    if arch:
        if arch == "none":
            out = [t for t in out if tag_arch(t) is None]
        else:
            out = [t for t in out if tag_arch(t) == arch]
    if pattern:
        rx = re.compile(pattern)
        out = [t for t in out if rx.search(t)]
    return out


def split_ref(ref):
    """Split 'host/path' into (host, repository), defaulting to cp.icr.io."""
    head, _, rest = ref.partition("/")
    if "." in head and rest:
        return head, rest
    return "cp.icr.io", ref


def get_token(host, user, password, repo):
    body = urllib.parse.urlencode({
        "service": "registry",
        "grant_type": "password",
        "client_id": "cp4d-entitlement-check",
        "username": user,
        "password": password,
        "scope": f"repository:{repo}:pull",
    }).encode()
    req = urllib.request.Request(f"https://{host}/oauth/token", data=body)
    try:
        with urllib.request.urlopen(req, timeout=30, context=SSL_CTX) as resp:
            return json.load(resp).get("token", ""), None
    except urllib.error.HTTPError as exc:
        return "", ("rejected", f"token HTTP {exc.code}")
    except ssl.SSLError as exc:
        return "", ("unreachable", f"TLS error: {exc}")
    except urllib.error.URLError as exc:
        reason = getattr(exc, "reason", exc)
        kind = "unreachable"
        if isinstance(reason, ssl.SSLError) or "CERTIFICATE_VERIFY_FAILED" in str(reason):
            return "", (kind, f"TLS error: {reason}")
        return "", (kind, f"network error: {reason}")
    except Exception as exc:
        return "", ("unreachable", f"error: {exc}")


def probe(ref):
    host, repo = split_ref(ref)
    if only and host not in only:
        return None
    if host not in creds:
        return {"registry": host, "repository": repo,
                "status": "NO CREDENTIAL", "detail": "host not in pull secret", "tags": []}

    user, password = creds[host]
    token, err = get_token(host, user, password, repo)
    if not token:
        # A rejected credential and an unreachable registry look similar from
        # here but mean opposite things: only the first says the key is bad.
        kind, detail = err if err else ("rejected", "no token issued")
        status = "AUTH FAILED" if kind == "rejected" else "UNREACHABLE"
        return {"registry": host, "repository": repo,
                "status": status, "detail": detail, "tags": []}

    req = urllib.request.Request(
        f"https://{host}/v2/{repo}/tags/list",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30, context=SSL_CTX) as resp:
            tags = json.load(resp).get("tags") or []
        return {"registry": host, "repository": repo, "status": "ENTITLED",
                "detail": f"{len(tags)} tags", "tags": tags}
    except urllib.error.HTTPError as exc:
        try:
            code = json.load(exc).get("errors", [{}])[0].get("code", "")
        except Exception:
            code = ""
        if code == "NAME_UNKNOWN":
            status, detail = "NOT FOUND", "no such repository on this host"
        elif exc.code in (401, 403) or code == "UNAUTHORIZED":
            status, detail = "NO ACCESS", "not entitled"
        else:
            status, detail = "ERROR", f"HTTP {exc.code} {code}".strip()
        return {"registry": host, "repository": repo,
                "status": status, "detail": detail, "tags": []}
    except Exception as exc:
        return {"registry": host, "repository": repo,
                "status": "ERROR", "detail": str(exc), "tags": []}


with ThreadPoolExecutor(max_workers=8) as pool:
    results = [r for r in pool.map(probe, repos) if r]

results.sort(key=lambda r: (r["registry"], r["repository"]))

if as_json:
    payload = {
        "pull_secret": secret_path,
        "registries": sorted(creds),
        "results": results if not quiet else [r for r in results if r["status"] == "ENTITLED"],
    }
    for r in payload["results"]:
        if not show_tags:
            r.pop("tags", None)
            continue
        selected = filter_tags(r["tags"], want_arch, want_grep)
        selected.sort(key=tag_sort_key)
        r["tag_count"] = len(r["tags"])
        r["tags"] = selected if tag_count <= 0 else selected[-tag_count:]
    print(json.dumps(payload, indent=2))
    sys.exit(0)

print()
print(f"Pull secret: {secret_path}")
print("icr.io credentials present for: " + ", ".join(
    f"{h} (user: {creds[h][0]})" for h in sorted(creds)))
print()

shown = [r for r in results if not quiet or r["status"] == "ENTITLED"]
if shown:
    width = max(len(f"{r['registry']}/{r['repository']}") for r in shown)
    current = None
    for r in shown:
        if r["registry"] != current:
            current = r["registry"]
            print(f"--- {current} ---")
        ref = f"{r['registry']}/{r['repository']}"
        print(f"  {ref:<{width}}  {r['status']:<12} {r['detail']}")
        if show_tags and r["status"] == "ENTITLED":
            selected = filter_tags(r["tags"], want_arch, want_grep)
            selected.sort(key=tag_sort_key)
            if not selected:
                print(f"      (no tags matched the filter; {len(r['tags'])} in total)")
                continue
            # Newest last, so the most relevant tag sits closest to the eye.
            shown_tags = selected if tag_count <= 0 else selected[-tag_count:]
            hidden = len(selected) - len(shown_tags)
            if hidden > 0:
                print(f"      ... {hidden} older tag(s) not shown")
            for t in shown_tags:
                print(f"      {t}")
    print()

counts = {}
for r in results:
    counts[r["status"]] = counts.get(r["status"], 0) + 1
print("Summary: " + ("  ".join(f"{k}: {v}" for k, v in sorted(counts.items())) or "nothing probed"))

entitled = counts.get("ENTITLED", 0)
if entitled:
    print(f"The credential can pull {entitled} of the {len(results)} repositories probed.")
if counts.get("AUTH FAILED"):
    print("AUTH FAILED means the registry refused the credential: the key is bad or expired.")
if counts.get("UNREACHABLE"):
    print("UNREACHABLE means the registry was never reached, so this says nothing about the key.")
    print("A TLS error here usually means this python3 has no CA store. Either run")
    print("'Install Certificates.command' for that interpreter, 'pip install certifi',")
    print("or point SSL_CERT_FILE at a CA bundle (e.g. /etc/ssl/cert.pem).")
if counts.get("NOT FOUND"):
    print("NOT FOUND is about the name, not entitlement: the repository is not on that host.")
print()
print("This is a probe of a fixed list, not a catalog listing: IBM Container")
print("Registry refuses catalog-scoped tokens, so no complete enumeration exists.")

# A bad key or an unusable connection are both failures worth signalling.
sys.exit(1 if (counts.get("AUTH FAILED") or counts.get("UNREACHABLE")) else 0)
PY

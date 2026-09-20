#!/bin/zsh
# Builds a CSV of every IBM CASE with latest version, display name, description
# and licenses.  The case list comes from `oc ibm-pak list` (run internally),
# unless you pass an existing CSV as the first argument:
#   ./ibm_case_data_review_fetch.sh [existing-list.csv]
#
# Metadata is read straight from each CASE's published version.yaml (~2-4 KB)
# rather than from its tarball (~200-500 KB), and the versions all come from a
# single repo-wide index, so the whole run is two small requests per case.
#
# Each metadata field is a toggle.  Set any of these to 0 to drop the column:
#   WANT_VERSION WANT_APP_VERSION WANT_DISPLAY_NAME WANT_DESCRIPTION
#   WANT_ORGANIZATION WANT_WEBPAGE WANT_LICENSES WANT_CATALOGS
#   WANT_CERTIFICATIONS WANT_CLASSIFICATIONS WANT_ARCHITECTURES
#   WANT_K8S_DISTROS WANT_MANAGED_PLATFORMS WANT_CREATED WANT_SOURCE
# WANT_FAILED_FLAG (default 1) adds a FAILED_PARSE column marking any row whose
# metadata could not be read; the reason is printed in the summary at the end.
# They default to 1.  WANT_ICON defaults to 0; set it to 1 to also decode each
# CASE icon to a PNG (written next to the CSV) and record its path.
#   WANT_ICON=1 WANT_LICENSES=0 ./ibm_case_data_review_fetch.sh
#
# LIMIT caps how many cases are retrieved, which is handy for a quick sample.
# It defaults to 0, meaning all of them:
#   LIMIT=20 ./ibm_case_data_review_fetch.sh
# It can also be given as the second argument, after the optional list file:
#   ./ibm_case_data_review_fetch.sh '' 20
#
# Set JOBS to change the fetch concurrency (default 12).

if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

OUT=~/Downloads/ibm-cases-detailed.csv
BASE=https://raw.githubusercontent.com/IBM/cloud-pak/master/repo/case
JOBS=${JOBS:-12}

# Number of cases to retrieve; 0 (the default) means all of them.  The second
# positional argument wins over the environment variable.
LIMIT=${2:-${LIMIT:-0}}
case $LIMIT in
  ''|*[!0-9]*) echo "LIMIT must be a non-negative integer, got '$LIMIT'." >&2; exit 1 ;;
esac

# ---- field toggles (all on by default except the icon) --------------------
WANT_VERSION=${WANT_VERSION:-1}
WANT_DISPLAY_NAME=${WANT_DISPLAY_NAME:-1}
WANT_DESCRIPTION=${WANT_DESCRIPTION:-1}
WANT_LICENSES=${WANT_LICENSES:-1}
WANT_SOURCE=${WANT_SOURCE:-1}
WANT_WEBPAGE=${WANT_WEBPAGE:-1}
WANT_APP_VERSION=${WANT_APP_VERSION:-1}
WANT_ORGANIZATION=${WANT_ORGANIZATION:-1}
WANT_CATALOGS=${WANT_CATALOGS:-1}
WANT_CERTIFICATIONS=${WANT_CERTIFICATIONS:-1}
WANT_CLASSIFICATIONS=${WANT_CLASSIFICATIONS:-1}
WANT_ARCHITECTURES=${WANT_ARCHITECTURES:-1}
WANT_K8S_DISTROS=${WANT_K8S_DISTROS:-1}
WANT_MANAGED_PLATFORMS=${WANT_MANAGED_PLATFORMS:-1}
WANT_CREATED=${WANT_CREATED:-1}
WANT_ICON=${WANT_ICON:-0}
WANT_FAILED_FLAG=${WANT_FAILED_FLAG:-1}

# Icons are decoded to real image files; the CSV records the path to each.
ICON_DIR=${ICON_DIR:-~/Downloads/ibm-case-icons}
[ "$WANT_ICON" = 1 ] && mkdir -p "$ICON_DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---- 1. Get the case list -------------------------------------------------
if [ -n "$1" ]; then
  cp "$1" "$TMP/list.csv"
else
  echo "Fetching case list with 'oc ibm-pak list'..." >&2
  oc ibm-pak list | grep -E '\S  +\S' | grep -v '^-' \
    | sed -E 's/[[:space:]]+$//; s/ {2,}/,/g' > "$TMP/list.csv"
fi
if [ ! -s "$TMP/list.csv" ]; then echo "No cases found." >&2; exit 1; fi

# Apply the cap now, before anything counts or fetches, keeping the header row.
if [ "$LIMIT" -gt 0 ]; then
  avail=$(($(wc -l < "$TMP/list.csv") - 1))
  if [ "$LIMIT" -lt "$avail" ]; then
    head -n $((LIMIT + 1)) "$TMP/list.csv" > "$TMP/list.trim" && mv "$TMP/list.trim" "$TMP/list.csv"
    echo "Limiting to $LIMIT of $avail cases." >&2
  fi
fi

# ---- 2. Latest versions, in one request -----------------------------------
# The repo-wide index lists latestVersion for every case, which saves a request
# per case.  Anything missing from it is looked up individually later.
echo "Fetching repo index..." >&2
curl -sfL "$BASE/index.yaml" -o "$TMP/root.yaml"
: > "$TMP/versions.txt"
if [ -s "$TMP/root.yaml" ]; then
  awk '/^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { n = $1; sub(/:$/, "", n); next }
       n != "" && /^[[:space:]]+latestVersion:/ { print n "\t" $2; n = "" }' \
    "$TMP/root.yaml" > "$TMP/versions.txt"
fi

# ---- parsers --------------------------------------------------------------
# Top-level scalars of the `case:` block.  Values may be plain, quoted, or
# folded over continuation lines; nested blocks (icons, licenses, supports)
# must not be picked up, which is why indent is matched exactly.
cat > "$TMP/fields.awk" <<'AWK'
BEGIN { incase = 0 }
/^case:[[:space:]]*$/ { incase = 1; next }
/^[A-Za-z]/ { incase = 0 }
incase {
  if ($0 ~ /^  [A-Za-z0-9_]+:/) {
    key = $0; sub(/^  /, "", key); sub(/:.*/, "", key)
    val = $0; sub(/^  [A-Za-z0-9_]+:[[:space:]]*/, "", val)
    cur = key; store[key] = val
    next
  }
  if (cur != "" && $0 ~ /^    [^ ]/ && $0 !~ /^    [A-Za-z0-9_-]+:/) {
    line = $0; sub(/^[[:space:]]+/, "", line)
    store[cur] = store[cur] " " line
    next
  }
  cur = ""
}
END {
  n = split(want, w, ",")
  for (i = 1; i <= n; i++) {
    v = store[w[i]]
    gsub(/^["']|["']$/, "", v)
    print w[i] "\t" v
  }
}
AWK

# Child keys of a nested collection under case.<blk> (licenses, catalogs,
# certifications, classifications) or case.supports.<blk> (architectures,
# k8sDistros, managedPlatforms), joined with ';'.
cat > "$TMP/collection.awk" <<'AWK'
BEGIN { incase = 0; inpar = (parent == "" ? 1 : 0); inblk = 0; ind = (parent == "" ? "    " : "      ") }
/^case:[[:space:]]*$/ { incase = 1; next }
/^[A-Za-z]/ { incase = 0; inpar = (parent == "" ? 1 : 0); inblk = 0 }
incase && parent != "" && $0 ~ ("^  " parent ":[[:space:]]*$") { inpar = 1; next }
incase && parent != "" && /^  [A-Za-z0-9_]+:/ { inpar = 0; inblk = 0 }
incase && inpar && $0 ~ ("^" (parent == "" ? "  " : "    ") blk ":[[:space:]]*$") { inblk = 1; next }
incase && inpar && inblk && $0 ~ ("^" (parent == "" ? "  " : "    ") "[A-Za-z0-9_]+:") { inblk = 0 }
inblk && $0 ~ ("^" ind "[A-Za-z0-9_.-]+:") {
  k = $0; sub("^" ind, "", k); sub(/:.*/, "", k)
  out = (out == "" ? k : out ";" k)
}
END { print out }
AWK

# First icon's base64 payload and media type, under case.icons.
cat > "$TMP/icon.awk" <<'AWK'
BEGIN { incase = 0; inico = 0 }
/^case:[[:space:]]*$/ { incase = 1; next }
/^[A-Za-z]/ { incase = 0; inico = 0 }
incase && /^  icons:[[:space:]]*$/ { inico = 1; next }
incase && /^  [A-Za-z0-9_]+:/ { inico = 0 }
inico && b == "" && /base64:/ { b = $0; sub(/^[^:]*:[[:space:]]*/, "", b) }
inico && m == "" && /mediaType:/ { m = $0; sub(/^[^:]*:[[:space:]]*/, "", m) }
END { print b; print m }
AWK

# ---- helpers --------------------------------------------------------------
# Quote a CSV cell.  Newlines, tabs and stray control characters are flattened
# to spaces so a malformed upstream value cannot break the row structure, and
# embedded double quotes are doubled per RFC 4180.
# Pure parameter expansion: this runs once per column per case, so forking
# tr/sed here costs more than the download does.  CSVQ holds the result.
csvq() {
  c_v=$1
  c_v=${c_v//$'\n'/ }; c_v=${c_v//$'\r'/ }; c_v=${c_v//$'\t'/ }
  c_v=${c_v//'"'/'""'}
  while [ "$c_v" != "${c_v//  / }" ]; do c_v=${c_v//  / }; done
  c_v=${c_v# }; c_v=${c_v% }
  CSVQ="\"$c_v\""
}

field() { awk -F'\t' -v k="$1" '$1 == k { sub(/^[^\t]*\t/, ""); print; exit }'; }

# ---- 3. Download every version.yaml up front ------------------------------
# Two phases beat interleaving here: the network is only a small part of the
# cost, while forking curl/awk/sed per case dominates.  One parallel download
# pass, then one parse pass, removes most of that overhead.
mkdir -p "$TMP/y"
total=$(($(wc -l < "$TMP/list.csv") - 1))

if [ -t 2 ]; then TTY=1; else TTY=0; fi

# Resolve each case to its version and build the curl argument list.
: > "$TMP/fetch.args"
: > "$TMP/meta.tsv"
idx=0
while IFS= read -r line; do
  idx=$((idx+1))
  name=${line%%,*}
  ver=$(awk -F'\t' -v n="$name" '$1 == n { print $2; exit }' "$TMP/versions.txt")
  printf '%s\t%s\t%s\n' "$idx" "$name" "$ver" >> "$TMP/meta.tsv"
  if [ -n "$ver" ]; then
    enc=$(printf '%s' "$ver" | sed 's/+/%2B/g')
    printf -- '-o\n%s\n%s\n' "$TMP/y/$idx.yaml" "$BASE/$name/$enc/version.yaml" >> "$TMP/fetch.args"
  fi
done < <(tail -n +2 "$TMP/list.csv")

echo "Downloading $total version.yaml files with $JOBS parallel jobs..." >&2
[ -s "$TMP/fetch.args" ] && xargs -P "$JOBS" -n 3 curl -sfL < "$TMP/fetch.args" 2>/dev/null

# Cases missing from the repo index get an individual lookup, as before.
while IFS="$(printf '\t')" read -r i n v; do
  [ -n "$v" ] && continue
  v=$(curl -sfL "$BASE/$n/index.yaml" | awk '/^latestVersion:/ {print $2}')
  [ -n "$v" ] || continue
  enc=$(printf '%s' "$v" | sed 's/+/%2B/g')
  curl -sfL -o "$TMP/y/$i.yaml" "$BASE/$n/$enc/version.yaml" 2>/dev/null
  awk -F'\t' -v i="$i" -v v="$v" 'BEGIN{OFS="\t"} $1==i{$3=v} {print}' \
    "$TMP/meta.tsv" > "$TMP/meta.new" && mv "$TMP/meta.new" "$TMP/meta.tsv"
done < "$TMP/meta.tsv"

# ---- 4. Parse everything in one pass --------------------------------------
echo "Parsing $total cases..." >&2

# Icons still need a decode step per case, so they stay in the shell loop.
extract_icon() {
  ic_name=$1; ic_yaml=$2; icon=""
  awk -f "$TMP/icon.awk" "$ic_yaml" > "$TMP/i.tmp" 2>/dev/null || : > "$TMP/i.tmp"
  b64=$(sed -n 1p "$TMP/i.tmp"); mt=$(sed -n 2p "$TMP/i.tmp")
  if [ -n "$b64" ]; then
    ext=${mt##*/}; ext=${ext%%+*}; ext=${ext%%;*}; [ -n "$ext" ] || ext=png
    if printf '%s' "$b64" | base64 -d > "$ICON_DIR/$ic_name.$ext" 2>/dev/null \
       && [ -s "$ICON_DIR/$ic_name.$ext" ]; then
      icon="$ICON_DIR/$ic_name.$ext"
    else
      rm -f "$ICON_DIR/$ic_name.$ext"
    fi
  fi
  rm -f "$TMP/i.tmp"
}

: > "$TMP/rows"
n=0
while IFS="$(printf '\t')" read -r i name ver; do
  n=$((n+1))
  [ "$TTY" = 1 ] && printf '\r\033[K[%d/%d] cases processed' "$n" "$total" >&2

  IFS= read -r line <&3
  vy="$TMP/y/$i.yaml"
  dname=""; desc=""; lic=""; web=""; src=""; icon=""; failed=""
  appv=""; org=""; cat=""; cert=""; cls=""; arch=""; k8s=""; mp=""; crt=""

  if [ -z "$ver" ]; then
    failed="no version found"
  elif [ ! -s "$vy" ]; then
    failed="version.yaml unavailable"
  else
    # One awk invocation returns every scalar field, instead of one per column.
    if fl=$(awk -v want="displayName,name,displayDescription,description,webPage,appVersion,organization" \
                -f "$TMP/fields.awk" "$vy" 2>/dev/null); then
      dname=$(printf '%s' "$fl" | field displayName)
      [ -n "$dname" ] || dname=$(printf '%s' "$fl" | field name)
      desc=$(printf '%s' "$fl" | field displayDescription)
      [ -n "$desc" ] || desc=$(printf '%s' "$fl" | field description)
      web=$(printf '%s' "$fl" | field webPage)
      # A few CASEs publish placeholders here rather than a real URL.
      case $web in TODO|todo|N/A|n/a|-) web="" ;; esac
      appv=$(printf '%s' "$fl" | field appVersion)
      org=$(printf '%s' "$fl" | field organization)
    else
      failed="field parse failed"
    fi
    # One helper covers every collection key; each is opt-out via its toggle.
    coll() { awk -v parent="$1" -v blk="$2" -f "$TMP/collection.awk" "$vy" 2>/dev/null; }
    [ "$WANT_LICENSES" = 1 ] && { lic=$(coll "" licenses) || {
      failed="${failed:-license parse failed}"; lic=""; }; }
    [ "$WANT_CATALOGS" = 1 ]           && cat=$(coll "" catalogs)
    [ "$WANT_CERTIFICATIONS" = 1 ]     && cert=$(coll "" certifications)
    [ "$WANT_CLASSIFICATIONS" = 1 ]    && cls=$(coll "" classifications)
    [ "$WANT_ARCHITECTURES" = 1 ]      && { arch=$(coll supports architectures)
      # one CASE spells it "architecture"
      [ -n "$arch" ] || arch=$(coll supports architecture); }
    [ "$WANT_K8S_DISTROS" = 1 ]        && k8s=$(coll supports k8sDistros)
    [ "$WANT_MANAGED_PLATFORMS" = 1 ]  && mp=$(coll supports managedPlatforms)
    # created/digest sit outside the case: block.
    [ "$WANT_CREATED" = 1 ] && crt=$(awk '/^created:/ { sub(/^created:[[:space:]]*/, ""); print; exit }' "$vy" 2>/dev/null)
    src="$name/$ver/version.yaml"
    [ "$WANT_ICON" = 1 ] && extract_icon "$name" "$vy"
  fi

  if [ -z "$failed" ] && [ -z "$dname" ] && [ -z "$desc" ]; then
    failed="no metadata in version.yaml"
  fi
  [ -n "$failed" ] && printf '%s\t%s\n' "$name" "$failed" >> "$TMP/skipped"

  row=$line
  [ "$WANT_VERSION" = 1 ]      && { csvq "$ver";    row="$row,$CSVQ"; }
  [ "$WANT_APP_VERSION" = 1 ]  && { csvq "$appv";   row="$row,$CSVQ"; }
  [ "$WANT_DISPLAY_NAME" = 1 ] && { csvq "$dname";  row="$row,$CSVQ"; }
  [ "$WANT_DESCRIPTION" = 1 ]  && { csvq "$desc";   row="$row,$CSVQ"; }
  [ "$WANT_ORGANIZATION" = 1 ]      && { csvq "$org";  row="$row,$CSVQ"; }
  [ "$WANT_LICENSES" = 1 ]          && { csvq "$lic";  row="$row,$CSVQ"; }
  [ "$WANT_CATALOGS" = 1 ]          && { csvq "$cat";  row="$row,$CSVQ"; }
  [ "$WANT_CERTIFICATIONS" = 1 ]    && { csvq "$cert"; row="$row,$CSVQ"; }
  [ "$WANT_CLASSIFICATIONS" = 1 ]   && { csvq "$cls";  row="$row,$CSVQ"; }
  [ "$WANT_ARCHITECTURES" = 1 ]     && { csvq "$arch"; row="$row,$CSVQ"; }
  [ "$WANT_K8S_DISTROS" = 1 ]       && { csvq "$k8s";  row="$row,$CSVQ"; }
  [ "$WANT_MANAGED_PLATFORMS" = 1 ] && { csvq "$mp";   row="$row,$CSVQ"; }
  [ "$WANT_CREATED" = 1 ]           && { csvq "$crt";  row="$row,$CSVQ"; }
  [ "$WANT_WEBPAGE" = 1 ]      && { csvq "$web";    row="$row,$CSVQ"; }
  [ "$WANT_ICON" = 1 ]         && { csvq "$icon";   row="$row,$CSVQ"; }
  [ "$WANT_SOURCE" = 1 ]       && { csvq "$src";    row="$row,$CSVQ"; }
  [ "$WANT_FAILED_FLAG" = 1 ]  && { csvq "$failed"; row="$row,$CSVQ"; }
  printf '%s\n' "$row" >> "$TMP/rows"
done 3< <(tail -n +2 "$TMP/list.csv") < "$TMP/meta.tsv"

# ---- 5. Assemble the CSV in the original order ----------------------------
hdr=$(head -1 "$TMP/list.csv")
[ "$WANT_VERSION" = 1 ]      && hdr="$hdr,LATEST_VERSION"
[ "$WANT_APP_VERSION" = 1 ]  && hdr="$hdr,APP_VERSION"
[ "$WANT_DISPLAY_NAME" = 1 ] && hdr="$hdr,DISPLAY_NAME"
[ "$WANT_DESCRIPTION" = 1 ]  && hdr="$hdr,DESCRIPTION"
[ "$WANT_ORGANIZATION" = 1 ]      && hdr="$hdr,ORGANIZATION"
[ "$WANT_LICENSES" = 1 ]          && hdr="$hdr,LICENSES"
[ "$WANT_CATALOGS" = 1 ]          && hdr="$hdr,CATALOGS"
[ "$WANT_CERTIFICATIONS" = 1 ]    && hdr="$hdr,CERTIFICATIONS"
[ "$WANT_CLASSIFICATIONS" = 1 ]   && hdr="$hdr,CLASSIFICATIONS"
[ "$WANT_ARCHITECTURES" = 1 ]     && hdr="$hdr,ARCHITECTURES"
[ "$WANT_K8S_DISTROS" = 1 ]       && hdr="$hdr,K8S_DISTROS"
[ "$WANT_MANAGED_PLATFORMS" = 1 ] && hdr="$hdr,MANAGED_PLATFORMS"
[ "$WANT_CREATED" = 1 ]           && hdr="$hdr,CREATED"
[ "$WANT_WEBPAGE" = 1 ]      && hdr="$hdr,WEB_PAGE"
[ "$WANT_ICON" = 1 ]         && hdr="$hdr,ICON_FILE"
[ "$WANT_SOURCE" = 1 ]       && hdr="$hdr,SOURCE_FILE"
[ "$WANT_FAILED_FLAG" = 1 ]  && hdr="$hdr,FAILED_PARSE"
echo "$hdr" > "$OUT"
cat "$TMP/rows" >> "$OUT"

[ "$TTY" = 1 ] && echo >&2
echo "Saved to $OUT" >&2

# Cases that yielded no (or partial) metadata are reported rather than hidden;
# they are still present in the CSV, just with empty columns.
if [ -s "$TMP/skipped" ]; then
  nskip=$(wc -l < "$TMP/skipped" | tr -d ' ')
  echo "$nskip case(s) had incomplete metadata:" >&2
  sort -u "$TMP/skipped" | sed 's/^/  - /; s/\t/: /' >&2
fi

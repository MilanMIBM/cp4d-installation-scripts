"""Helpers to deploy a public container image as an IBM Cloud Code Engine application.

The entry point is :func:`deploy_public_image_app`. Give it IBM Cloud credentials,
a Code Engine project, and *any* of the following references to a public image:

* a bare Docker Hub image name              -> ``memgraph/memgraph-mage``
* a single-name official Docker Hub image   -> ``nginx`` / ``library/nginx``
* a Docker Hub web URL                       -> ``https://hub.docker.com/r/memgraph/memgraph``
* a fully qualified registry reference       -> ``ghcr.io/owner/app:1.2.3``
* a GitHub release/tag URL                   -> ``https://github.com/marimo-team/marimo/releases/tag/0.23.9``

The function figures out what to do automatically and either:

1. deploys the app for real with the ``ibm-code-engine-sdk`` (default), or
2. with ``ui_instructions_only=True`` returns a Markdown document describing exactly
   what to click in the Code Engine console to achieve the same effect.

Design goal: **always avoid copying the image into IBM Cloud Container Registry**.
Code Engine can pull public images directly, so the common path references the public
image as-is. A registry copy/build is only attempted when the source is not a directly
pullable OCI image (for example a GitHub repository that must be built from source), and
only when a target ``icr_namespace`` is provided.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from typing import Optional
from urllib.parse import urlparse

# ---------------------------------------------------------------------------
# Environment variable names
# ---------------------------------------------------------------------------
#
# Every input that this module needs can be supplied through an environment
# variable. The *names* below are the contract; values are read at call time so
# the caller is free to load a .env file (e.g. python-dotenv) beforehand. Any
# value passed explicitly to a function always wins over the environment.

ENV_API_KEY = "IBM_CLOUD_APIKEY"

ENV_CR_REGION = "CONTAINER_REGISTRY_REGION"
ENV_CR_REGION_LOCALNAME = "CONTAINER_REGISTRY_REGION_LOCALNAME"
ENV_CR_REGION_PRIVATE_LOCALNAME = "CONTAINER_REGISTRY_REGION_PRIVATE_LOCALNAME"
ENV_CR_NAMESPACE = "CONTAINER_REGISTRY_NAMESPACE"

ENV_CE_PROJECT_REGION = "CODE_ENGINE_PROJECT_REGION"
ENV_CE_PROJECT_ID = "CODE_ENGINE_PROJECT_ID"
ENV_CE_CR_ACCESS_SECRET = "CODE_ENGINE_CR_ACCESS_SECRET"

# Region used when nothing is supplied explicitly or via the environment.
DEFAULT_REGION = "eu-de"


def _env(name: str) -> Optional[str]:
    """Return a non-empty, stripped environment value, or None."""
    value = os.environ.get(name)
    if value is None:
        return None
    value = value.strip()
    return value or None


# ---------------------------------------------------------------------------
# Region / registry reference data
# ---------------------------------------------------------------------------

# Code Engine API endpoints, keyed by IBM Cloud region.
CODE_ENGINE_ENDPOINTS = {
    "us-south": "https://api.us-south.codeengine.cloud.ibm.com/v2",
    "us-east": "https://api.us-east.codeengine.cloud.ibm.com/v2",
    "eu-de": "https://api.eu-de.codeengine.cloud.ibm.com/v2",
    "eu-gb": "https://api.eu-gb.codeengine.cloud.ibm.com/v2",
    "eu-es": "https://api.eu-es.codeengine.cloud.ibm.com/v2",
    "jp-tok": "https://api.jp-tok.codeengine.cloud.ibm.com/v2",
    "jp-osa": "https://api.jp-osa.codeengine.cloud.ibm.com/v2",
    "au-syd": "https://api.au-syd.codeengine.cloud.ibm.com/v2",
    "ca-tor": "https://api.ca-tor.codeengine.cloud.ibm.com/v2",
    "br-sao": "https://api.br-sao.codeengine.cloud.ibm.com/v2",
}

# IBM Cloud Container Registry domain names, keyed by region.
ICR_DOMAINS = {
    "global": "icr.io",
    "us-south": "us.icr.io",
    "br-sao": "br.icr.io",
    "ca-tor": "ca.icr.io",
    "ca-mon": "ca2.icr.io",
    "eu-de": "de.icr.io",
    "eu-es": "es.icr.io",
    "eu-gb": "uk.icr.io",
    "in-che": "in.icr.io",
    "in-mum": "in2.icr.io",
    "jp-osa": "jp2.icr.io",
    "jp-tok": "jp.icr.io",
    "au-syd": "au.icr.io",
}

# Code Engine listens on 8080 by default and reserves a handful of ports.
RESERVED_PORTS = {8022, 8008, 8012, 9090, 9091, 15090}


# ---------------------------------------------------------------------------
# Configuration sizing presets
# ---------------------------------------------------------------------------

# Memory must be paired with a valid CPU value per the Code Engine
# "Supported memory and CPU combinations" table. These presets stay within
# the documented balanced combinations.
SIZE_PRESETS = {
    "nano": {"cpu": "0.125", "memory": "0.25G", "ephemeral_storage": "0.25G"},
    "xsmall": {"cpu": "0.25", "memory": "0.5G", "ephemeral_storage": "0.4G"},
    "small": {"cpu": "0.5", "memory": "1G", "ephemeral_storage": "0.4G"},
    "medium": {"cpu": "1", "memory": "2G", "ephemeral_storage": "0.4G"},
    "large": {"cpu": "2", "memory": "4G", "ephemeral_storage": "0.4G"},
    "xlarge": {"cpu": "4", "memory": "8G", "ephemeral_storage": "0.4G"},
    "2xlarge": {"cpu": "8", "memory": "16G", "ephemeral_storage": "0.4G"},
    "3xlarge": {"cpu": "12", "memory": "32G", "ephemeral_storage": "0.4G"},
}

DEFAULT_SIZE = "medium"


@dataclass
class AppScaleConfig:
    """Compute and autoscaling configuration for the Code Engine app."""

    cpu: str = "1"
    memory: str = "2G"
    ephemeral_storage: str = "0.4G"
    min_instances: int = 0  # scale to zero when idle
    max_instances: int = 1
    concurrency: int = 100
    request_timeout: int = 300
    port: Optional[int] = None  # None -> Code Engine default (8080)

    @classmethod
    def from_size(cls, size: str = DEFAULT_SIZE, **overrides) -> "AppScaleConfig":
        """Build a scale config from a named preset, with optional field overrides."""
        preset = SIZE_PRESETS.get(size)
        if preset is None:
            valid = ", ".join(SIZE_PRESETS)
            raise ValueError(f"Unknown size '{size}'. Valid sizes: {valid}")
        cfg = cls(
            cpu=preset["cpu"],
            memory=preset["memory"],
            ephemeral_storage=preset["ephemeral_storage"],
        )
        for key, value in overrides.items():
            if not hasattr(cfg, key):
                raise ValueError(f"Unknown scale config field '{key}'")
            setattr(cfg, key, value)
        if cfg.port is not None and cfg.port in RESERVED_PORTS:
            raise ValueError(
                f"Port {cfg.port} is reserved by Code Engine. "
                f"Reserved ports: {sorted(RESERVED_PORTS)}"
            )
        return cfg


# ---------------------------------------------------------------------------
# Image reference parsing
# ---------------------------------------------------------------------------


@dataclass
class ImageRef:
    """A resolved container image reference.

    Attributes:
        registry:    Registry host, e.g. ``docker.io``, ``ghcr.io``, ``us.icr.io``.
        namespace:   Namespace / org / user, e.g. ``memgraph`` or ``library``.
        repository:  Repository name, e.g. ``memgraph-mage``.
        tag:         Tag, e.g. ``latest`` or ``0.23.9``.
        directly_pullable:
                     True if Code Engine can pull this image as-is (an OCI image in a
                     public registry). False means it needs to be built first (e.g. a
                     GitHub repo that only ships source / release archives).
        source_url:  For non-pullable sources, the git/source URL to build from.
        source_revision:
                     For git sources, the branch/tag/commit to build.
        needs_secret:
                     True if pulling requires registry credentials (private registry).
        notes:       Human-readable notes about how the reference was resolved.
    """

    registry: str
    namespace: str
    repository: str
    tag: str = "latest"
    directly_pullable: bool = True
    source_url: Optional[str] = None
    source_revision: Optional[str] = None
    needs_secret: bool = False
    notes: list = field(default_factory=list)

    @property
    def full_reference(self) -> str:
        """Fully qualified ``registry/namespace/repository:tag`` reference."""
        parts = [self.registry, self.namespace, self.repository]
        path = "/".join(p for p in parts if p)
        return f"{path}:{self.tag}"

    @property
    def short_reference(self) -> str:
        """Reference without the implicit Docker Hub registry, as users usually type it."""
        if self.registry == "docker.io":
            if self.namespace == "library":
                return f"{self.repository}:{self.tag}"
            return f"{self.namespace}/{self.repository}:{self.tag}"
        return self.full_reference

    def suggested_app_name(self) -> str:
        """A valid Code Engine app name derived from the repository name.

        App names: lowercase, start with a letter, end alphanumeric, <=55 chars,
        only letters/numbers/hyphens.
        """
        name = re.sub(r"[^a-z0-9-]+", "-", self.repository.lower()).strip("-")
        if not name or not name[0].isalpha():
            name = f"app-{name}".strip("-")
        name = name[:55].rstrip("-")
        return name or "my-app"


_KNOWN_REGISTRY_HOSTS = (
    "icr.io",
    "ghcr.io",
    "quay.io",
    "registry.gitlab.com",
    "public.ecr.aws",
    "gcr.io",
    "mcr.microsoft.com",
    "registry.k8s.io",
)


def _looks_like_registry_host(token: str) -> bool:
    """Heuristic: does the first path segment look like a registry hostname?"""
    if token in ("docker.io", "index.docker.io", "registry.hub.docker.com"):
        return True
    if token.endswith(_KNOWN_REGISTRY_HOSTS):
        return True
    # A host has a dot or a port, and is not just "user".
    return ("." in token or ":" in token) and "/" not in token


def _split_repo_tag(token: str) -> tuple[str, str]:
    """Split ``repo:tag`` (or ``repo@sha256:...``) into (repo, tag)."""
    if "@" in token:
        repo, digest = token.split("@", 1)
        return repo, digest  # keep the digest as the "tag" reference
    if ":" in token:
        repo, tag = token.rsplit(":", 1)
        return repo, tag
    return token, "latest"


def parse_image_reference(reference: str) -> ImageRef:
    """Parse any supported image reference into a normalized :class:`ImageRef`.

    Accepts bare names, Docker Hub URLs, fully-qualified registry refs, and
    GitHub release/tag URLs. Raises ``ValueError`` if nothing usable is found.
    """
    if not reference or not reference.strip():
        raise ValueError("Empty image reference")
    reference = reference.strip()

    # --- URL forms -------------------------------------------------------
    if reference.startswith(("http://", "https://")):
        parsed = urlparse(reference)
        host = parsed.netloc.lower()
        path = parsed.path.strip("/")

        if "hub.docker.com" in host:
            return _parse_docker_hub_url(path, reference)
        if "github.com" in host:
            return _parse_github_url(path, parsed, reference)
        if host.endswith(_KNOWN_REGISTRY_HOSTS) or host.endswith("icr.io"):
            # e.g. https://ghcr.io/owner/app:tag
            return _parse_registry_path(host, path)
        raise ValueError(
            f"Unsupported URL host '{host}'. Supported: hub.docker.com, github.com, "
            f"and known OCI registries ({', '.join(_KNOWN_REGISTRY_HOSTS)})."
        )

    # --- Plain image reference ------------------------------------------
    first = reference.split("/", 1)[0]
    if _looks_like_registry_host(first):
        host, _, rest = reference.partition("/")
        return _parse_registry_path(host, rest)

    # No registry host -> Docker Hub.
    return _parse_docker_hub_image(reference)


def _parse_docker_hub_image(image: str) -> ImageRef:
    """Parse a bare Docker Hub image such as ``memgraph/memgraph-mage`` or ``nginx``."""
    repo_part, tag = _split_repo_tag(image)
    segments = repo_part.split("/")
    if len(segments) == 1:
        namespace, repository = "library", segments[0]
        note = "Official Docker Hub image; namespace defaults to 'library'."
    else:
        namespace, repository = segments[0], "/".join(segments[1:])
        note = "Public Docker Hub image."
    return ImageRef(
        registry="docker.io",
        namespace=namespace,
        repository=repository,
        tag=tag,
        directly_pullable=True,
        notes=[note, "Code Engine can pull this directly; no ICR copy required."],
    )


def _parse_docker_hub_url(path: str, original: str) -> ImageRef:
    """Parse a hub.docker.com web URL into an image reference.

    Examples:
        r/memgraph/memgraph            -> memgraph/memgraph
        _/nginx                        -> library/nginx (official)
        layers/memgraph/memgraph/...   -> memgraph/memgraph
    """
    segments = [s for s in path.split("/") if s]
    tag = "latest"
    if not segments:
        raise ValueError(f"Could not parse Docker Hub URL: {original}")

    if segments[0] == "r" and len(segments) >= 3:
        namespace, repository = segments[1], segments[2]
    elif segments[0] == "r" and len(segments) == 2:
        # Official images sometimes appear as /r/library/<name> or /r/<name>
        namespace, repository = "library", segments[1]
    elif segments[0] == "_" and len(segments) >= 2:
        namespace, repository = "library", segments[1]
    elif segments[0] == "layers" and len(segments) >= 3:
        namespace, repository = segments[1], segments[2]
        if len(segments) >= 5:  # /layers/ns/repo/<tag>/<digest>
            tag = segments[3]
    else:
        # Fall back: treat first two segments as namespace/repo
        namespace = segments[0]
        repository = segments[1] if len(segments) > 1 else segments[0]

    return ImageRef(
        registry="docker.io",
        namespace=namespace,
        repository=repository,
        tag=tag,
        directly_pullable=True,
        notes=[
            f"Resolved from Docker Hub URL: {original}",
            "Code Engine can pull this directly; no ICR copy required.",
        ],
    )


def _parse_github_url(path: str, parsed, original: str) -> ImageRef:
    """Parse a github.com URL.

    Release/tag URLs (``/owner/repo/releases/tag/<tag>``) and plain repo URLs are
    treated as *source* that must be built, because a GitHub repo is not itself an
    OCI image. The resulting :class:`ImageRef` carries the git source so the caller
    can build it (only if a target ICR namespace is supplied).
    """
    segments = [s for s in path.split("/") if s]
    if len(segments) < 2:
        raise ValueError(f"Could not parse GitHub URL: {original}")
    owner, repo = segments[0], segments[1]
    if repo.endswith(".git"):
        repo = repo[:-4]

    revision = None
    if "releases" in segments:
        idx = segments.index("releases")
        # .../releases/tag/<tag>  or  .../releases/download/<tag>/...
        if idx + 2 < len(segments) and segments[idx + 1] in ("tag", "download"):
            revision = segments[idx + 2]
    elif "tree" in segments:
        idx = segments.index("tree")
        if idx + 1 < len(segments):
            revision = segments[idx + 1]

    git_url = f"https://github.com/{owner}/{repo}"
    return ImageRef(
        registry="docker.io",  # placeholder; not used while not directly pullable
        namespace=owner,
        repository=repo,
        tag=revision or "latest",
        directly_pullable=False,
        source_url=git_url,
        source_revision=revision,
        notes=[
            f"Resolved from GitHub URL: {original}",
            "GitHub source is not an OCI image; it must be built before deployment.",
            "A build requires a target ICR namespace to store the resulting image.",
        ],
    )


def _parse_registry_path(host: str, rest: str) -> ImageRef:
    """Parse ``<host>/<namespace>/<repo>:<tag>`` for an explicit registry host."""
    host = host.lower()
    if host in ("index.docker.io", "registry.hub.docker.com"):
        host = "docker.io"
    repo_part, tag = _split_repo_tag(rest)
    segments = [s for s in repo_part.split("/") if s]
    if not segments:
        raise ValueError(f"No repository found after registry host '{host}'")
    if len(segments) == 1:
        namespace = "library" if host == "docker.io" else ""
        repository = segments[0]
    else:
        namespace = segments[0]
        repository = "/".join(segments[1:])

    needs_secret = host.endswith("icr.io")  # private ICR namespaces need a secret
    return ImageRef(
        registry=host,
        namespace=namespace,
        repository=repository,
        tag=tag,
        directly_pullable=True,
        needs_secret=needs_secret,
        notes=[
            f"Fully-qualified reference for registry '{host}'.",
            "Private registries (including ICR) require a registry access secret."
            if needs_secret
            else "Public registry; no registry secret required.",
        ],
    )


# ---------------------------------------------------------------------------
# Image inspection (Entrypoint / Cmd / ExposedPorts / User)
# ---------------------------------------------------------------------------
#
# The Code Engine docs ("Defining commands and arguments for your workloads")
# explain that an image carries `Entrypoint` (Code Engine `command`) and `Cmd`
# (Code Engine `args`). Code Engine runs the image's own metadata by default, so
# you only need to set command/args to *override* them. To advise on this in the
# UI walkthrough, we read the image's OCI config from the registry. This fetches
# only the small manifest + config JSON (a few KB) over the registry v2 API with
# anonymous pull tokens - it does not pull image layers.

# Registry hosts that we know how to authenticate against anonymously for public
# images. Keyed by ImageRef.registry -> (api_host, token_auth_url_template).
_REGISTRY_V2_HOSTS = {
    "docker.io": "registry-1.docker.io",
    "ghcr.io": "ghcr.io",
    "quay.io": "quay.io",
    "public.ecr.aws": "public.ecr.aws",
    "gcr.io": "gcr.io",
    "registry.k8s.io": "registry.k8s.io",
    "mcr.microsoft.com": "mcr.microsoft.com",
}

_OCI_ACCEPT_HEADERS = ", ".join(
    [
        "application/vnd.oci.image.manifest.v1+json",
        "application/vnd.oci.image.index.v1+json",
        "application/vnd.docker.distribution.manifest.v2+json",
        "application/vnd.docker.distribution.manifest.list.v2+json",
    ]
)


@dataclass
class ImageRuntimeInfo:
    """Runtime metadata read from an image's OCI config.

    Attributes:
        entrypoint: The image ``Entrypoint`` array (Code Engine ``command``), or None.
        cmd: The image ``Cmd`` array (Code Engine ``args``), or None.
        exposed_ports: Sorted list of integer ports declared via ``EXPOSE``.
        user: The image ``User`` (may be empty -> runs as root).
        working_dir: The image ``WorkingDir``.
        env: ``{NAME: VALUE}`` baked into the image.
        inspected: True if the metadata was successfully fetched.
        error: Populated with a short reason when inspection failed/was skipped.
    """

    entrypoint: Optional[list] = None
    cmd: Optional[list] = None
    exposed_ports: list = field(default_factory=list)
    user: str = ""
    working_dir: str = ""
    env: dict = field(default_factory=dict)
    inspected: bool = False
    error: Optional[str] = None

    @property
    def effective_command(self) -> list:
        """The command line the container runs by default (Entrypoint + Cmd)."""
        return (self.entrypoint or []) + (self.cmd or [])

    @property
    def runs_as_root(self) -> bool:
        """True if the image does not set a non-root user."""
        user = (self.user or "").strip()
        if not user:
            return True
        uid = user.split(":", 1)[0]
        return uid in ("", "0", "root")

    @property
    def primary_port(self) -> Optional[int]:
        """First non-reserved exposed port, if any."""
        for port in self.exposed_ports:
            if port not in RESERVED_PORTS:
                return port
        return self.exposed_ports[0] if self.exposed_ports else None


def inspect_image_runtime(image_ref: ImageRef, *, timeout: int = 15) -> ImageRuntimeInfo:
    """Fetch ``Entrypoint``/``Cmd``/``ExposedPorts``/``User`` for a public image.

    Best-effort and never raises: any network/parse problem is captured in the
    returned :class:`ImageRuntimeInfo.error` with ``inspected=False`` so callers
    (the UI walkthrough) can degrade gracefully.
    """
    info = ImageRuntimeInfo()

    if not image_ref.directly_pullable:
        info.error = "Source is built from a repository; no image metadata to inspect yet."
        return info
    if image_ref.needs_secret:
        info.error = "Private registry; skipping anonymous inspection."
        return info

    api_host = _REGISTRY_V2_HOSTS.get(image_ref.registry)
    if not api_host:
        info.error = f"Inspection not supported for registry '{image_ref.registry}'."
        return info

    try:
        import requests  # local import: only needed for inspection
    except ImportError:
        info.error = "The 'requests' package is required for image inspection."
        return info

    repo = image_ref.repository
    if image_ref.registry == "docker.io":
        # Docker Hub repos are namespaced (library/<name> for official images).
        repo = f"{image_ref.namespace or 'library'}/{repo}"
    elif image_ref.namespace:
        repo = f"{image_ref.namespace}/{repo}"

    try:
        session = requests.Session()
        token = _get_anonymous_pull_token(session, api_host, repo, timeout)
        headers = {"Accept": _OCI_ACCEPT_HEADERS}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        base = f"https://{api_host}/v2/{repo}"
        manifest = _get_json(session, f"{base}/manifests/{image_ref.tag}", headers, timeout)

        # If this is a multi-arch index, pick a linux/amd64 manifest.
        if manifest.get("manifests"):
            digest = _pick_platform_digest(manifest["manifests"])
            if not digest:
                info.error = "No linux/amd64 manifest found in image index."
                return info
            manifest = _get_json(session, f"{base}/manifests/{digest}", headers, timeout)

        config_digest = manifest.get("config", {}).get("digest")
        if not config_digest:
            info.error = "Image manifest has no config blob (unexpected schema)."
            return info

        config = _get_json(session, f"{base}/blobs/{config_digest}", headers, timeout)
        _populate_runtime_info(info, config)
        info.inspected = True
    except Exception as exc:  # best-effort: never break the caller
        info.error = f"Inspection failed: {type(exc).__name__}: {exc}"

    return info


def _get_anonymous_pull_token(session, api_host, repo, timeout):
    """Obtain an anonymous bearer token via the registry's WWW-Authenticate challenge."""
    resp = session.get(f"https://{api_host}/v2/", timeout=timeout)
    if resp.status_code != 401:
        return None  # registry allows anonymous access without a token
    challenge = resp.headers.get("WWW-Authenticate", "")
    realm = _parse_auth_param(challenge, "realm")
    service = _parse_auth_param(challenge, "service")
    if not realm:
        return None
    params = {"scope": f"repository:{repo}:pull"}
    if service:
        params["service"] = service
    token_resp = session.get(realm, params=params, timeout=timeout)
    token_resp.raise_for_status()
    data = token_resp.json()
    return data.get("token") or data.get("access_token")


def _parse_auth_param(header: str, key: str) -> Optional[str]:
    match = re.search(rf'{key}="([^"]+)"', header)
    return match.group(1) if match else None


def _get_json(session, url, headers, timeout):
    resp = session.get(url, headers=headers, timeout=timeout)
    resp.raise_for_status()
    return resp.json()


def _pick_platform_digest(manifests: list) -> Optional[str]:
    """Choose linux/amd64 (preferred) from a manifest index, else first linux entry."""
    fallback = None
    for entry in manifests:
        platform = entry.get("platform", {})
        if platform.get("os") == "linux" and platform.get("architecture") == "amd64":
            return entry.get("digest")
        if platform.get("os") == "linux" and fallback is None:
            fallback = entry.get("digest")
    return fallback


def _populate_runtime_info(info: ImageRuntimeInfo, config: dict) -> None:
    """Extract the relevant fields from an OCI image config document."""
    cfg = config.get("config") or {}
    info.entrypoint = cfg.get("Entrypoint")
    info.cmd = cfg.get("Cmd")
    info.user = cfg.get("User") or ""
    info.working_dir = cfg.get("WorkingDir") or ""

    ports = []
    for raw in (cfg.get("ExposedPorts") or {}):
        # Keys look like "8080/tcp"; keep the numeric part.
        num = raw.split("/", 1)[0]
        if num.isdigit():
            ports.append(int(num))
    info.exposed_ports = sorted(set(ports))

    env = {}
    for item in (cfg.get("Env") or []):
        if "=" in item:
            name, value = item.split("=", 1)
            env[name] = value
    info.env = env


# ---------------------------------------------------------------------------
# Result container
# ---------------------------------------------------------------------------


@dataclass
class DeploymentResult:
    """Outcome of :func:`deploy_public_image_app`."""

    mode: str  # "deployed" or "ui_instructions"
    app_name: str
    image_ref: ImageRef
    scale: AppScaleConfig
    app_url: Optional[str] = None  # populated when deployed
    instructions_markdown: Optional[str] = None  # populated for ui_instructions
    raw_app: Optional[dict] = None  # raw SDK response when deployed
    runtime_info: Optional["ImageRuntimeInfo"] = None  # image metadata (UI mode)


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def deploy_public_image_app(
    *,
    image: str,
    api_key: Optional[str] = None,
    region: Optional[str] = None,
    project_id: Optional[str] = None,
    app_name: Optional[str] = None,
    size: str = DEFAULT_SIZE,
    scale_overrides: Optional[dict] = None,
    ui_instructions_only: bool = False,
    icr_namespace: Optional[str] = None,
    registry_secret: Optional[str] = None,
    env_variables: Optional[dict] = None,
    visibility: str = "public",
    inspect_image: bool = True,
    overwrite_current_instance: bool = False,
) -> DeploymentResult:
    """Set up a Code Engine application for a public container image.

    Any argument left as ``None`` is resolved from the environment (see the
    ``ENV_*`` constants); an explicit value always takes precedence. ``region``
    falls back to :data:`CODE_ENGINE_PROJECT_REGION`, then
    :data:`CONTAINER_REGISTRY_REGION`, then :data:`DEFAULT_REGION` (``eu-de``).

    Args:
        image: Any supported image reference (see module docstring). Required.
        api_key: IBM Cloud IAM API key. Falls back to ``$IBM_CLOUD_APIKEY``.
        region: Code Engine region. Falls back to ``$CODE_ENGINE_PROJECT_REGION`` /
            ``$CONTAINER_REGISTRY_REGION`` / ``eu-de``.
        project_id: Code Engine project GUID. Falls back to ``$CODE_ENGINE_PROJECT_ID``.
        app_name: App name; defaults to a value derived from the repository.
        size: A named size preset (see :data:`SIZE_PRESETS`).
        scale_overrides: Optional dict of :class:`AppScaleConfig` field overrides.
        ui_instructions_only: If True, do not call the API; return Markdown UI steps.
        icr_namespace: Target ICR namespace. Falls back to
            ``$CONTAINER_REGISTRY_NAMESPACE``. Used when building a non-pullable
            source, or as the namespace for a private ICR pull secret.
        registry_secret: Existing Code Engine registry secret name to reuse. Falls
            back to ``$CODE_ENGINE_CR_ACCESS_SECRET``.
        env_variables: Optional ``{NAME: VALUE}`` literal environment variables.
        visibility: ``public``, ``private``, or ``project``.
        inspect_image: Read the image's OCI config (Entrypoint/Cmd/ExposedPorts/User)
            from the registry. In ``ui_instructions_only`` mode it advises on Code
            Engine ``command``/``args`` and port. On a real deployment it auto-fills
            the listening port when you did not set one and the image exposes a single
            non-reserved port (so traffic reaches the right port). It never overrides
            the image's command/args - Code Engine runs the image's own
            Entrypoint/Cmd by default. Best-effort; set False to skip the network call.
        overwrite_current_instance: If True and an app with ``app_name`` already exists
            in the project, delete it first and recreate it. If False (default), an
            existing app raises an error instead of being replaced.

    Returns:
        A :class:`DeploymentResult`. ``runtime_info`` is populated whenever
        ``inspect_image`` ran (both modes).
    """
    api_key = api_key or _env(ENV_API_KEY)
    region = (
        region
        or _env(ENV_CE_PROJECT_REGION)
        or _env(ENV_CR_REGION)
        or DEFAULT_REGION
    )
    project_id = project_id or _env(ENV_CE_PROJECT_ID)
    icr_namespace = icr_namespace or _env(ENV_CR_NAMESPACE)
    registry_secret = registry_secret or _env(ENV_CE_CR_ACCESS_SECRET)

    if region not in CODE_ENGINE_ENDPOINTS:
        valid = ", ".join(CODE_ENGINE_ENDPOINTS)
        raise ValueError(
            f"Region '{region}' is not a Code Engine region. Valid: {valid}"
        )
    if visibility not in ("public", "private", "project"):
        raise ValueError("visibility must be one of: public, private, project")

    image_ref = parse_image_reference(image)
    scale = AppScaleConfig.from_size(size, **(scale_overrides or {}))
    final_app_name = app_name or image_ref.suggested_app_name()

    if ui_instructions_only:
        runtime_info = (
            inspect_image_runtime(image_ref) if inspect_image else ImageRuntimeInfo()
        )
        md = render_ui_instructions(
            region=region,
            project_id=project_id or "<your-project-id>",
            image_ref=image_ref,
            app_name=final_app_name,
            scale=scale,
            icr_namespace=icr_namespace,
            registry_secret=registry_secret,
            env_variables=env_variables,
            visibility=visibility,
            runtime_info=runtime_info,
        )
        return DeploymentResult(
            mode="ui_instructions",
            app_name=final_app_name,
            image_ref=image_ref,
            scale=scale,
            instructions_markdown=md,
            runtime_info=runtime_info,
        )

    # Direct deployment needs the required inputs to actually be present.
    missing = [
        label
        for label, value in (
            (f"api_key/${ENV_API_KEY}", api_key),
            (f"project_id/${ENV_CE_PROJECT_ID}", project_id),
        )
        if not value
    ]
    if missing:
        raise ValueError(
            "Missing required input(s) for deployment: "
            + ", ".join(missing)
            + ". Provide them explicitly or via environment variables, or use "
            "ui_instructions_only=True."
        )

    if not image_ref.directly_pullable and not icr_namespace:
        raise ValueError(
            f"Image source '{image}' is not a directly pullable OCI image and must be "
            f"built first. Provide 'icr_namespace' (or set ${ENV_CR_NAMESPACE}) so the "
            f"built image can be stored, or call again with ui_instructions_only=True "
            f"to see manual build steps."
        )

    runtime_info = (
        inspect_image_runtime(image_ref) if inspect_image else ImageRuntimeInfo()
    )

    return _deploy_with_sdk(
        api_key=api_key,
        region=region,
        project_id=project_id,
        image_ref=image_ref,
        app_name=final_app_name,
        scale=scale,
        icr_namespace=icr_namespace,
        registry_secret=registry_secret,
        env_variables=env_variables,
        visibility=visibility,
        runtime_info=runtime_info,
        overwrite_current_instance=overwrite_current_instance,
    )


# ---------------------------------------------------------------------------
# SDK-backed deployment
# ---------------------------------------------------------------------------


def _build_code_engine_client(api_key: str, region: str):
    """Construct an authenticated Code Engine SDK client for the given region."""
    try:
        from ibm_cloud_sdk_core.authenticators import IAMAuthenticator
        from ibm_code_engine_sdk.code_engine_v2 import CodeEngineV2
    except ImportError as exc:  # pragma: no cover - dependency guidance
        raise ImportError(
            "The 'ibm-code-engine-sdk' package is required to deploy directly. "
            "Install it with: pip install ibm-code-engine-sdk\n"
            "Alternatively, call deploy_public_image_app(..., ui_instructions_only=True) "
            "to generate manual console instructions instead."
        ) from exc

    authenticator = IAMAuthenticator(api_key)
    client = CodeEngineV2(authenticator=authenticator)
    client.set_service_url(CODE_ENGINE_ENDPOINTS[region])
    return client


def _ensure_registry_secret(
    client, project_id: str, region: str, icr_namespace: str, api_key: str,
    secret_name: Optional[str] = None,
) -> str:
    """Create (idempotently) a Code Engine registry secret for ICR and return its name.

    ``secret_name`` defaults to ``$CODE_ENGINE_CR_ACCESS_SECRET`` if set, otherwise to
    ``icr-access-secret``. If a secret with that name already exists it is reused as-is.
    """
    secret_name = secret_name or _env(ENV_CE_CR_ACCESS_SECRET) or "icr-access-secret"
    server = ICR_DOMAINS.get(region, "icr.io")
    try:
        client.get_secret(project_id=project_id, name=secret_name)
        return secret_name
    except Exception:
        pass
    client.create_secret(
        project_id=project_id,
        format="registry",
        name=secret_name,
        data={
            "server": server,
            "username": "iamapikey",
            "password": api_key,
        },
    )
    return secret_name


def _build_and_push_image(
    client, project_id, region, image_ref, icr_namespace, secret_name
) -> str:
    """Run a Code Engine build for a non-pullable (git) source, return the output image.

    This is the fallback path for GitHub sources. It creates a build, starts a build
    run, and returns the ICR reference the app should use. The build run completes
    asynchronously; callers may need to wait before the app becomes Ready.
    """
    domain = ICR_DOMAINS.get(region, "icr.io")
    tag = image_ref.tag if image_ref.tag != "latest" else "latest"
    output_image = f"{domain}/{icr_namespace}/{image_ref.repository}:{tag}"
    build_name = f"build-{image_ref.suggested_app_name()}"[:63]

    try:
        client.get_build(project_id=project_id, name=build_name)
    except Exception:
        client.create_build(
            project_id=project_id,
            name=build_name,
            output_image=output_image,
            output_secret=secret_name,
            strategy_type="dockerfile",
            source_type="git",
            source_url=image_ref.source_url,
            source_revision=image_ref.source_revision,
            strategy_size="medium",
        )
    client.create_build_run(project_id=project_id, build_name=build_name)
    return output_image


def _deploy_with_sdk(
    *,
    api_key,
    region,
    project_id,
    image_ref,
    app_name,
    scale,
    icr_namespace,
    registry_secret,
    env_variables,
    visibility,
    runtime_info=None,
    overwrite_current_instance=False,
) -> DeploymentResult:
    client = _build_code_engine_client(api_key, region)
    runtime_info = runtime_info or ImageRuntimeInfo()

    # If the image exposes a single non-reserved port and the caller did not pin a
    # port, route Code Engine traffic to that port instead of the 8080 default.
    if scale.port is None and runtime_info.inspected:
        primary = runtime_info.primary_port
        if primary is not None and primary not in RESERVED_PORTS:
            scale.port = primary

    image_secret = None
    image_reference = image_ref.full_reference

    if not image_ref.directly_pullable:
        # GitHub / source: build into ICR first.
        image_secret = _ensure_registry_secret(
            client, project_id, region, icr_namespace, api_key,
            secret_name=registry_secret,
        )
        image_reference = _build_and_push_image(
            client, project_id, region, image_ref, icr_namespace, image_secret
        )
    elif image_ref.needs_secret:
        # Private ICR reference: needs a pull secret.
        image_secret = _ensure_registry_secret(
            client, project_id, region, icr_namespace or image_ref.namespace, api_key,
            secret_name=registry_secret,
        )

    run_env = _env_dict_to_prototype(env_variables)

    create_kwargs = dict(
        project_id=project_id,
        name=app_name,
        image_reference=image_reference,
        scale_cpu_limit=scale.cpu,
        scale_memory_limit=scale.memory,
        scale_ephemeral_storage_limit=scale.ephemeral_storage,
        scale_min_instances=scale.min_instances,
        scale_max_instances=scale.max_instances,
        scale_concurrency=scale.concurrency,
        scale_request_timeout=scale.request_timeout,
        managed_domain_mappings="local_public"
        if visibility == "public"
        else ("local_private" if visibility == "private" else "local"),
    )
    if image_secret:
        create_kwargs["image_secret"] = image_secret
    if scale.port is not None:
        create_kwargs["image_port"] = scale.port
    if run_env:
        create_kwargs["run_env_variables"] = run_env

    _handle_existing_app(client, project_id, app_name, overwrite_current_instance)

    response = client.create_app(**create_kwargs)
    app = response.get_result()

    app_url = None
    for endpoint_key in ("endpoint", "endpoint_internal"):
        if app.get(endpoint_key):
            app_url = app[endpoint_key]
            break

    return DeploymentResult(
        mode="deployed",
        app_name=app_name,
        image_ref=image_ref,
        scale=scale,
        app_url=app_url,
        raw_app=app,
        runtime_info=runtime_info if runtime_info.inspected else None,
    )


def _handle_existing_app(client, project_id, app_name, overwrite_current_instance) -> None:
    """Check for an existing app of the same name and act per the overwrite flag.

    If the app exists and ``overwrite_current_instance`` is True, delete it (and wait
    for the delete to settle) so it can be recreated. If it exists and the flag is
    False, raise so the caller does not silently clobber a running workload.
    """
    try:
        existing = client.get_app(project_id=project_id, name=app_name)
    except Exception:
        return  # not found (or transient) -> proceed to create

    # get_app returned something -> the app exists.
    if not overwrite_current_instance:
        raise FileExistsError(
            f"A Code Engine app named '{app_name}' already exists in project "
            f"'{project_id}'. Pass overwrite_current_instance=True to replace it, or "
            f"choose a different app_name."
        )

    client.delete_app(project_id=project_id, name=app_name)
    _wait_until_app_absent(client, project_id, app_name)
    del existing  # response not needed beyond the existence check


def _wait_until_app_absent(client, project_id, app_name, attempts=30, delay=2.0) -> None:
    """Poll until the named app no longer exists, so a recreate won't 409."""
    import time

    for _ in range(attempts):
        try:
            client.get_app(project_id=project_id, name=app_name)
        except Exception:
            return  # gone
        time.sleep(delay)
    # Fall through: best-effort. create_app will surface a clear error if still present.


def _env_dict_to_prototype(env_variables: Optional[dict]) -> Optional[list]:
    """Turn ``{NAME: VALUE}`` into the SDK's ``run_env_variables`` literal format."""
    if not env_variables:
        return None
    return [
        {"type": "literal", "name": name, "value": str(value)}
        for name, value in env_variables.items()
    ]


# ---------------------------------------------------------------------------
# UI instructions generation
# ---------------------------------------------------------------------------


def render_ui_instructions(
    *,
    region,
    project_id,
    image_ref,
    app_name,
    scale,
    icr_namespace,
    env_variables,
    visibility,
    registry_secret=None,
    runtime_info=None,
) -> str:
    """Render a Markdown document with exact Code Engine console steps."""
    lines: list[str] = []
    a = lines.append
    secret_name = registry_secret or _env(ENV_CE_CR_ACCESS_SECRET) or "icr-access-secret"
    runtime_info = runtime_info or ImageRuntimeInfo()

    a(f"# Deploy `{app_name}` to IBM Cloud Code Engine (console)")
    a("")
    a(f"_Generated UI walkthrough - region **{region}**, project `{project_id}`._")
    a("")

    a("## Resolved image")
    a("")
    a(f"- **Source reference:** `{image_ref.short_reference}`")
    a(f"- **Full reference:** `{image_ref.full_reference}`")
    a(f"- **Registry:** `{image_ref.registry}`")
    a(f"- **Directly pullable:** {'yes' if image_ref.directly_pullable else 'no'}")
    for note in image_ref.notes:
        a(f"- _{note}_")
    a("")

    a("## Target configuration")
    a("")
    a("| Setting | Value |")
    a("| --- | --- |")
    a(f"| Application name | `{app_name}` |")
    a(f"| CPU | `{scale.cpu}` vCPU |")
    a(f"| Memory | `{scale.memory}` |")
    a(f"| Ephemeral storage | `{scale.ephemeral_storage}` |")
    a(f"| Min instances | `{scale.min_instances}` |")
    a(f"| Max instances | `{scale.max_instances}` |")
    a(f"| Concurrency | `{scale.concurrency}` |")
    a(f"| Request timeout | `{scale.request_timeout}` s |")
    a(
        f"| Listening port | `{scale.port if scale.port is not None else '8080 (default)'}` |"
    )
    a(f"| Visibility | `{visibility}` |")
    a("")

    if not image_ref.directly_pullable:
        _render_build_section(a, region, image_ref, icr_namespace, secret_name)

    _render_command_args_section(a, runtime_info, scale)

    a("## Steps")
    a("")
    a("1. Open the [Code Engine console](https://cloud.ibm.com/codeengine/overview).")
    a("2. Select **Let's go**, then **Application**.")
    a(f"3. Enter the application name: **`{app_name}`**.")
    a(
        f"4. Select your project (the one with ID `{project_id}` in region `{region}`). "
        f"If it does not exist yet, click **Create** to make a new project first."
    )

    if image_ref.directly_pullable and not image_ref.needs_secret:
        a(
            "5. Under **Code**, choose **Container image** and click **Configure image**."
        )
        a(f"   - **Registry server:** `{image_ref.registry}`")
        a("   - **Registry secret:** `None` (this is a public image).")
        a(f"   - **Namespace:** `{image_ref.namespace}`")
        a(f"   - **Repository:** `{image_ref.repository}`")
        a(f"   - **Tag:** `{image_ref.tag}`")
        a("   - Click **Done**.")
    else:
        built = (
            f"{ICR_DOMAINS.get(region, 'icr.io')}/{icr_namespace}/"
            f"{image_ref.repository}:{image_ref.tag}"
            if not image_ref.directly_pullable
            else image_ref.full_reference
        )
        a(
            "5. Under **Code**, choose **Container image** and click **Configure image**."
        )
        a(f"   - **Image reference:** `{built}`")
        a(
            f"   - **Registry secret:** `{secret_name}` (a secret that can read this "
            "registry; create a **Registry secret** with username `iamapikey` and your "
            "IBM Cloud API key as the password if one does not exist)."
        )
        a("   - Click **Done**.")

    a("6. Expand **Runtime settings** and set:")
    a(f"   - **CPU and memory:** `{scale.cpu} vCPU / {scale.memory}`")
    a(f"   - **Ephemeral storage:** `{scale.ephemeral_storage}`")
    a(f"   - **Min number of instances:** `{scale.min_instances}`")
    a(f"   - **Max number of instances:** `{scale.max_instances}`")
    a(f"   - **Concurrency:** `{scale.concurrency}`")
    a(f"   - **Request timeout:** `{scale.request_timeout}`")
    if scale.port is not None:
        a(f"   - **Listening port:** `{scale.port}`")

    vis_label = {"public": "Public", "private": "Private", "project": "Project"}[
        visibility
    ]
    a(f"7. Under **Endpoints**, set visibility to **{vis_label}**.")

    if env_variables:
        a(
            "8. Expand **Environment variables** and add each of the following as "
            "**Literal value**:"
        )
        for name, value in env_variables.items():
            a(f"   - `{name}` = `{value}`")
        a("9. Click **Create**.")
        a(
            "10. Wait for the status to become **Ready**, then click **Test application** "
            "or open the **Application URL**."
        )
    else:
        a("8. Click **Create**.")
        a(
            "9. Wait for the status to become **Ready**, then click **Test application** "
            "or open the **Application URL**."
        )

    a("")
    a("## Equivalent CLI")
    a("")
    a("```bash")
    a(
        _render_cli(
            region,
            project_id,
            image_ref,
            app_name,
            scale,
            icr_namespace,
            env_variables,
            visibility,
            secret_name,
        )
    )
    a("```")
    a("")
    return "\n".join(lines)


def _render_build_section(a, region, image_ref, icr_namespace, secret_name) -> None:
    """Append the build-from-source console section for GitHub sources."""
    domain = ICR_DOMAINS.get(region, "icr.io")
    ns = icr_namespace or "<your-namespace>"
    output = f"{domain}/{ns}/{image_ref.repository}:{image_ref.tag}"
    a("## Build required (GitHub source)")
    a("")
    a(
        "This reference points at GitHub source, not a ready-made image, so Code Engine "
        "must build it into IBM Cloud Container Registry first."
    )
    a("")
    a("1. In the Code Engine console, open your project and select **Image builds**.")
    a("2. Click **Create** and configure:")
    a(f"   - **Name:** `build-{image_ref.suggested_app_name()}`")
    a("   - **Source:** Source code from a **Git repository**")
    a(f"   - **Repository URL:** `{image_ref.source_url}`")
    if image_ref.source_revision:
        a(f"   - **Branch/Revision:** `{image_ref.source_revision}`")
    a("   - **Strategy:** `Dockerfile`")
    a(f"   - **Output image:** `{output}`")
    a(
        f"   - **Registry secret:** `{secret_name}` (a secret with `iamapikey` + your "
        "IBM Cloud API key)."
    )
    a("3. Click **Create** and then **Run build**. Wait for it to succeed.")
    a("4. Use the output image above as the application's container image below.")
    a("")


def _fmt_str_array(values) -> str:
    """Render a string array the way Code Engine / Docker shows it: ["a", "b"]."""
    if not values:
        return "_(empty)_"
    return "`[" + ", ".join(f'"{v}"' for v in values) + "]`"


def _render_command_args_section(a, runtime_info, scale) -> None:
    """Append guidance on Code Engine command/args based on image metadata.

    Per the Code Engine docs, an image's ``Entrypoint`` maps to Code Engine
    ``command`` and its ``Cmd`` maps to ``args``. Code Engine runs the image's own
    metadata by default; you only set command/args to override it.
    """
    a("## Commands and arguments")
    a("")

    if not runtime_info.inspected:
        reason = runtime_info.error or "Image metadata was not inspected."
        a(f"> Could not read the image's command metadata. _{reason}_")
        a("")
        a(
            "Leave **Command** and **Arguments** empty to run the image's built-in "
            "`ENTRYPOINT`/`CMD`. Only set them if you need to override the image "
            "defaults (see the table below)."
        )
        a("")
        _render_command_override_table(a)
        return

    entry = runtime_info.entrypoint
    cmd = runtime_info.cmd
    effective = runtime_info.effective_command

    a("Read from the image's OCI config:")
    a("")
    a("| Image field | Code Engine field | Value |")
    a("| --- | --- | --- |")
    a(f"| `Entrypoint` | **Command** | {_fmt_str_array(entry)} |")
    a(f"| `Cmd` | **Arguments** | {_fmt_str_array(cmd)} |")
    a("")
    if effective:
        a(f"By default the container runs: `{' '.join(effective)}`")
    else:
        a(
            "> The image declares **no** `Entrypoint`/`Cmd`. You **must** provide a "
            "**Command** (and optionally **Arguments**) or the container has nothing "
            "to run."
        )
    a("")
    a(
        "**Recommendation:** leave **Command** and **Arguments** empty in the console "
        "to use these built-in values as-is. Override them only to change behavior:"
    )
    a("")
    _render_command_override_table(a)

    # User / root note.
    if runtime_info.runs_as_root:
        a(
            "> The image does not set a non-root `User`. Code Engine can still run it, "
            "but consider an image that runs as non-root for least privilege."
        )
        a("")
    elif runtime_info.user:
        a(f"- Image runs as user `{runtime_info.user}`.")
        a("")

    # Port advice based on EXPOSE vs. the configured listening port.
    declared = runtime_info.exposed_ports
    if declared:
        a(f"- Image `EXPOSE`s: {', '.join(str(p) for p in declared)}.")
        chosen = scale.port if scale.port is not None else 8080
        primary = runtime_info.primary_port
        if primary is not None and primary != chosen:
            a(
                f"  - **Port mismatch:** Code Engine will send traffic to `{chosen}` "
                f"but the image listens on `{primary}`. Set the app **Listening port** "
                f"to `{primary}` (or pass `scale_overrides={{'port': {primary}}}`)."
            )
        a("")


def _render_command_override_table(a) -> None:
    """The Entrypoint/Cmd override semantics table from the Code Engine docs."""
    a("| If you set... | Effect |")
    a("| --- | --- |")
    a("| **Command** (`--command`) | Overrides the image `Entrypoint`; image `Cmd` is ignored. |")
    a("| **Arguments** (`--argument`) | Overrides the image `Cmd`. |")
    a("| neither | The image's own `Entrypoint` + `Cmd` run unchanged. |")
    a("")


def _render_cli(
    region,
    project_id,
    image_ref,
    app_name,
    scale,
    icr_namespace,
    env_variables,
    visibility,
    secret_name="icr-access-secret",
) -> str:
    """Build the equivalent `ibmcloud ce` CLI commands as a single block."""
    cmds: list[str] = []
    cmds.append(f"ibmcloud target -r {region}")
    cmds.append(f"ibmcloud ce project select --id {project_id}")

    if not image_ref.directly_pullable:
        domain = ICR_DOMAINS.get(region, "icr.io")
        ns = icr_namespace or "<your-namespace>"
        output = f"{domain}/{ns}/{image_ref.repository}:{image_ref.tag}"
        build_name = f"build-{image_ref.suggested_app_name()}"
        cmds.append(
            f"ibmcloud ce secret create --format registry --name {secret_name} \\\n"
            f"  --server {domain} --username iamapikey --password ${ENV_API_KEY}"
        )
        rev = (
            f" \\\n  --commit {image_ref.source_revision}"
            if image_ref.source_revision
            else ""
        )
        cmds.append(
            f"ibmcloud ce build create --name {build_name} \\\n"
            f"  --source {image_ref.source_url}{rev} \\\n"
            f"  --strategy dockerfile \\\n"
            f"  --image {output} \\\n"
            f"  --registry-secret {secret_name}"
        )
        cmds.append(f"ibmcloud ce buildrun submit --build {build_name} --wait")
        image_for_app = output
        secret_flag = f" \\\n  --registry-secret {secret_name}"
    elif image_ref.needs_secret:
        domain = ICR_DOMAINS.get(region, "icr.io")
        cmds.append(
            f"ibmcloud ce secret create --format registry --name {secret_name} \\\n"
            f"  --server {domain} --username iamapikey --password ${ENV_API_KEY}"
        )
        image_for_app = image_ref.full_reference
        secret_flag = f" \\\n  --registry-secret {secret_name}"
    else:
        image_for_app = image_ref.short_reference
        secret_flag = ""

    vis_flag = ""
    if visibility != "public":
        vis_flag = f" \\\n  --visibility {visibility}"

    port_flag = f" \\\n  --port {scale.port}" if scale.port is not None else ""

    env_flags = ""
    if env_variables:
        env_flags = "".join(
            f" \\\n  --env {name}={value}" for name, value in env_variables.items()
        )

    cmds.append(
        f"ibmcloud ce app create --name {app_name} \\\n"
        f"  --image {image_for_app}{secret_flag} \\\n"
        f"  --cpu {scale.cpu} \\\n"
        f"  --memory {scale.memory} \\\n"
        f"  --ephemeral-storage {scale.ephemeral_storage} \\\n"
        f"  --min-scale {scale.min_instances} \\\n"
        f"  --max-scale {scale.max_instances} \\\n"
        f"  --concurrency {scale.concurrency} \\\n"
        f"  --request-timeout {scale.request_timeout}"
        f"{port_flag}{vis_flag}{env_flags}"
    )
    cmds.append(f"ibmcloud ce app get --name {app_name} --output url")
    return "\n\n".join(cmds)

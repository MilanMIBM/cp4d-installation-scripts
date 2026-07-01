"""Generate IBM Cloud Code Engine-compatible Dockerfiles.

This follows the best practices from the Code Engine docs ("Writing a Dockerfile
for Code Engine"):

* **Multi-stage builds** for compiled / built runtimes, so build tools and sources
  are not shipped in the runtime image.
* **Tiny base images** (Alpine / distroless / slim) to reduce image size and attack
  surface.
* **Combined ``RUN`` statements** so package installs collapse into a single layer
  and caches are cleaned in the same layer.
* **Non-root ``USER``** (defaults to UID/GID ``1100``), optionally creating a named
  user + home directory.
* **``EXPOSE 8080``** and ``WORKDIR /app`` - 8080 is the Code Engine default port and
  ``/app`` avoids clobbering reserved OS directories.

The entry point is :func:`generate_dockerfile`, which returns the Dockerfile text and
can optionally write it to a directory using the ``<imagename>_Dockerfile`` naming
scheme via :func:`save_dockerfile`.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from typing import Optional

# ---------------------------------------------------------------------------
# Environment variable names
# ---------------------------------------------------------------------------
#
# The Dockerfile generator itself is registry-agnostic, but when you save a file
# it can take naming hints from the same environment used by the deployment
# helper. Explicit arguments always win over the environment.

ENV_CR_NAMESPACE = "CONTAINER_REGISTRY_NAMESPACE"
ENV_DOCKERFILE_OUTPUT_DIR = "CODE_ENGINE_DOCKERFILE_DIR"


def _env(name: str) -> Optional[str]:
    """Return a non-empty, stripped environment value, or None."""
    value = os.environ.get(name)
    if value is None:
        return None
    value = value.strip()
    return value or None


# Reserved directories that must not be used as an app directory (per the docs).
_RESERVED_APP_DIRS = {
    "/bin",
    "/dev",
    "/etc",
    "/lib",
    "/proc",
    "/run",
    "/sys",
    "/usr",
    "/var",
    "/workspace",
    "/",
}

# Supported runtime presets. Each describes how to build a Code Engine-friendly
# image for that language/runtime.
RUNTIMES = (
    "node",  # Node.js service (npm install, run a server)
    "node-static",  # Built front-end (React/Angular/Vue) served as static files
    "python",  # Python service (pip install, run a module/app)
    "go",  # Go binary -> scratch/distroless (native, no runtime)
    "java-maven",  # Maven build -> JRE runtime
    "static",  # Plain static site served by nginx-unprivileged
    "generic",  # Single prebuilt binary/script, minimal base
)

DEFAULT_PORT = 8080
DEFAULT_UID = 1100
DEFAULT_GID = 1100


@dataclass
class DockerfileConfig:
    """Inputs that shape the generated Dockerfile.

    Args:
        runtime: One of :data:`RUNTIMES`.
        app_dir: In-container app directory (best practice: ``/app``).
        port: Port the app listens on; ``EXPOSE``d and reported to Code Engine.
        non_root: Emit a ``USER`` line to run as non-root.
        uid / gid: UID/GID for the non-root user.
        create_named_user: Also create a named user + home dir (needed if the app
            requires ``$HOME`` to exist).
        base_image: Override the default base image for the chosen runtime.
        builder_image: Override the default builder-stage base image (compiled runtimes).
        entrypoint: ENTRYPOINT as a list (exec form). Defaults are runtime-specific.
        install_packages: Extra OS packages to install in a single combined ``RUN``.
        env: ``{NAME: VALUE}`` environment variables baked into the image.
        copy_source: The ``COPY`` source path from the build context (default ``.``).
        extra_build_commands: Extra shell commands appended to the build/install step.
        node_start_command / python_module / go_main_package / etc. are runtime hints.
    """

    runtime: str = "generic"
    app_dir: str = "/app"
    port: int = DEFAULT_PORT
    non_root: bool = True
    uid: int = DEFAULT_UID
    gid: int = DEFAULT_GID
    create_named_user: bool = False
    base_image: Optional[str] = None
    builder_image: Optional[str] = None
    entrypoint: Optional[list] = None
    install_packages: list = field(default_factory=list)
    env: dict = field(default_factory=dict)
    copy_source: str = "."
    extra_build_commands: list = field(default_factory=list)

    # Runtime-specific hints (only the relevant ones are used).
    node_version: str = "20"
    node_start_command: list = field(default_factory=lambda: ["npm", "run", "start"])
    python_version: str = "3.12"
    python_module: Optional[str] = None  # e.g. "app:app" or "main.py"
    python_run_command: Optional[list] = None  # overrides module-based default
    go_version: str = "1.22"
    go_main_package: str = "."
    go_runtime_base: str = "gcr.io/distroless/static-debian12"
    java_builder_image: str = "maven:3-eclipse-temurin-21"
    java_runtime_image: str = "eclipse-temurin:21-jre-alpine"
    java_jar_glob: str = "/app/target/*.jar"

    def validate(self) -> None:
        if self.runtime not in RUNTIMES:
            raise ValueError(
                f"Unknown runtime '{self.runtime}'. Valid: {', '.join(RUNTIMES)}"
            )
        norm = "/" + self.app_dir.strip("/") if self.app_dir.strip("/") else "/"
        if norm in _RESERVED_APP_DIRS:
            raise ValueError(
                f"app_dir '{self.app_dir}' is reserved. Use a subdirectory like /app."
            )
        if not (0 < self.port < 65536):
            raise ValueError(f"port {self.port} is out of range")


# ---------------------------------------------------------------------------
# Shared snippet builders
# ---------------------------------------------------------------------------


def _env_lines(env: dict) -> list:
    return [f'ENV {k}="{v}"' for k, v in env.items()]


def _combined_apt_install(packages: list) -> str:
    """A single-layer apt install with cache cleanup (Debian/Ubuntu bases)."""
    pkgs = " ".join(packages)
    return (
        "RUN \\\n"
        "    apt-get update && \\\n"
        f"    apt-get install -y --no-install-recommends {pkgs} && \\\n"
        "    apt-get clean && \\\n"
        "    rm -rf /var/lib/apt/lists/*"
    )


def _combined_apk_install(packages: list) -> str:
    """A single-layer apk install (Alpine bases); --no-cache avoids leftover index."""
    pkgs = " ".join(packages)
    return f"RUN apk add --no-cache {pkgs}"


def _nonroot_lines(cfg: DockerfileConfig, alpine: bool) -> list:
    """USER line, optionally preceded by user/group creation."""
    lines: list = []
    if not cfg.non_root:
        return lines
    if cfg.create_named_user:
        if alpine:
            lines.append(
                "RUN addgroup nonroot --gid {gid} && \\\n"
                "    adduser nonroot --ingroup nonroot --uid {uid} "
                "--home /home/nonroot --disabled-password".format(
                    uid=cfg.uid, gid=cfg.gid
                )
            )
        else:
            lines.append(
                "RUN groupadd --gid {gid} nonroot && \\\n"
                "    useradd --uid {uid} --gid {gid} --create-home "
                "--home-dir /home/nonroot nonroot".format(uid=cfg.uid, gid=cfg.gid)
            )
    lines.append(f"USER {cfg.uid}:{cfg.gid}")
    return lines


# ---------------------------------------------------------------------------
# Per-runtime generators
# ---------------------------------------------------------------------------


def _gen_node(cfg: DockerfileConfig) -> list:
    base = cfg.base_image or f"node:{cfg.node_version}-alpine"
    lines = [f"FROM {base}", ""]
    if cfg.install_packages:
        lines += [_combined_apk_install(cfg.install_packages), ""]
    lines += [
        f"WORKDIR {cfg.app_dir}",
        f"COPY {cfg.copy_source} {cfg.app_dir}",
        "",
        "RUN npm install --omit=dev" + _join_extra(cfg),
        "",
    ]
    lines += _env_lines(cfg.env)
    lines += _nonroot_lines(cfg, alpine=True)
    lines += [f"EXPOSE {cfg.port}"]
    entry = cfg.entrypoint or cfg.node_start_command
    lines.append(_exec_form("ENTRYPOINT", entry))
    return lines


def _gen_node_static(cfg: DockerfileConfig) -> list:
    """Built SPA (React/Angular/Vue): build in one stage, serve static in a tiny one."""
    builder = cfg.builder_image or f"node:{cfg.node_version}-alpine"
    runtime = cfg.base_image or f"node:{cfg.node_version}-alpine"
    lines = [
        f"FROM {builder} AS builder",
        "",
        f"WORKDIR {cfg.app_dir}",
        f"COPY {cfg.copy_source} {cfg.app_dir}",
        "RUN npm install && npm run build" + _join_extra(cfg),
        "",
        f"FROM {runtime}",
        "",
        "RUN npm install -g serve",
        "",
        f"COPY --from=builder {cfg.app_dir}/build {cfg.app_dir}",
        "",
    ]
    lines += _env_lines(cfg.env)
    lines += _nonroot_lines(cfg, alpine=True)
    lines += [f"EXPOSE {cfg.port}"]
    entry = cfg.entrypoint or [
        "serve",
        "--single",
        "--no-clipboard",
        "--listen",
        str(cfg.port),
        cfg.app_dir,
    ]
    lines.append(_exec_form("ENTRYPOINT", entry))
    return lines


def _gen_python(cfg: DockerfileConfig) -> list:
    base = cfg.base_image or f"python:{cfg.python_version}-slim"
    alpine = "alpine" in base
    lines = [f"FROM {base}", ""]
    lines += [
        'ENV PYTHONUNBUFFERED="1"',
        'ENV PIP_NO_CACHE_DIR="1"',
        "",
    ]
    if cfg.install_packages:
        installer = _combined_apk_install if alpine else _combined_apt_install
        lines += [installer(cfg.install_packages), ""]
    lines += [
        f"WORKDIR {cfg.app_dir}",
        f"COPY {cfg.copy_source} {cfg.app_dir}",
        "",
        "RUN pip install --no-cache-dir -r requirements.txt" + _join_extra(cfg),
        "",
    ]
    lines += _env_lines(cfg.env)
    lines += _nonroot_lines(cfg, alpine=alpine)
    lines += [f"EXPOSE {cfg.port}"]
    if cfg.python_run_command:
        entry = cfg.python_run_command
    elif cfg.python_module:
        # Assume an ASGI/WSGI module "package:app"; fall back to running a file.
        if ":" in cfg.python_module:
            entry = cfg.entrypoint or [
                "python",
                "-m",
                "uvicorn",
                cfg.python_module,
                "--host",
                "0.0.0.0",
                "--port",
                str(cfg.port),
            ]
        else:
            entry = cfg.entrypoint or ["python", cfg.python_module]
    else:
        entry = cfg.entrypoint or ["python", "app.py"]
    lines.append(_exec_form("ENTRYPOINT", entry))
    return lines


def _gen_go(cfg: DockerfileConfig) -> list:
    """Compile to a static binary, ship on distroless/scratch (no runtime needed)."""
    builder = cfg.builder_image or f"golang:{cfg.go_version}-alpine"
    runtime = cfg.base_image or cfg.go_runtime_base
    lines = [
        f"FROM {builder} AS builder",
        "",
        f"WORKDIR {cfg.app_dir}",
        "COPY go.* ./",
        "RUN go mod download",
        f"COPY {cfg.copy_source} {cfg.app_dir}",
        f'RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" '
        f"-o /app/server {cfg.go_main_package}" + _join_extra(cfg),
        "",
        f"FROM {runtime}",
        "",
        "COPY --from=builder /app/server /app/server",
        "",
    ]
    lines += _env_lines(cfg.env)
    # Emit a numeric USER for least privilege; works on distroless and scratch alike
    # (a numeric UID needs no /etc/passwd entry).
    if cfg.non_root:
        lines.append(f"USER {cfg.uid}:{cfg.gid}")
    lines += [f"EXPOSE {cfg.port}"]
    entry = cfg.entrypoint or ["/app/server"]
    lines.append(_exec_form("ENTRYPOINT", entry))
    return lines


def _gen_java_maven(cfg: DockerfileConfig) -> list:
    """Maven build stage -> small JRE runtime stage, copying just the JAR."""
    builder = cfg.builder_image or cfg.java_builder_image
    runtime = cfg.base_image or cfg.java_runtime_image
    alpine = "alpine" in runtime
    lines = [
        f"FROM {builder} AS builder",
        "",
        f"WORKDIR {cfg.app_dir}",
        f"COPY {cfg.copy_source} {cfg.app_dir}",
        "RUN mvn -q package -DskipTests" + _join_extra(cfg),
        "",
        f"FROM {runtime}",
        "",
        f"WORKDIR {cfg.app_dir}",
        f"COPY --from=builder {cfg.java_jar_glob} {cfg.app_dir}/application.jar",
        "",
    ]
    lines += _env_lines(cfg.env)
    lines += _nonroot_lines(cfg, alpine=alpine)
    lines += [f"EXPOSE {cfg.port}"]
    entry = cfg.entrypoint or ["java", "-jar", f"{cfg.app_dir}/application.jar"]
    lines.append(_exec_form("ENTRYPOINT", entry))
    return lines


def _gen_static(cfg: DockerfileConfig) -> list:
    """Serve a prebuilt static site with the unprivileged nginx image."""
    base = cfg.base_image or "nginxinc/nginx-unprivileged:alpine"
    port = cfg.port
    lines = [
        f"FROM {base}",
        "",
        f"COPY {cfg.copy_source} /usr/share/nginx/html",
        "",
    ]
    lines += _env_lines(cfg.env)
    # nginx-unprivileged already runs as uid 101; only override if asked explicitly.
    if cfg.non_root and (cfg.uid, cfg.gid) != (DEFAULT_UID, DEFAULT_GID):
        lines.append(f"USER {cfg.uid}:{cfg.gid}")
    lines += [
        f"EXPOSE {port}",
        "# Note: the default nginx-unprivileged image listens on 8080.",
    ]
    if cfg.entrypoint:
        lines.append(_exec_form("ENTRYPOINT", cfg.entrypoint))
    return lines


def _gen_generic(cfg: DockerfileConfig) -> list:
    """A minimal single-stage image for a prebuilt binary or script."""
    base = cfg.base_image or "alpine:3.20"
    alpine = "alpine" in base
    lines = [f"FROM {base}", ""]
    if cfg.install_packages:
        installer = _combined_apk_install if alpine else _combined_apt_install
        lines += [installer(cfg.install_packages), ""]
    lines += [
        f"WORKDIR {cfg.app_dir}",
        f"COPY {cfg.copy_source} {cfg.app_dir}",
        "",
    ]
    if cfg.extra_build_commands:
        lines += ["RUN " + " && \\\n    ".join(cfg.extra_build_commands), ""]
    lines += _env_lines(cfg.env)
    lines += _nonroot_lines(cfg, alpine=alpine)
    lines += [f"EXPOSE {cfg.port}"]
    if cfg.entrypoint:
        lines.append(_exec_form("ENTRYPOINT", cfg.entrypoint))
    return lines


_GENERATORS = {
    "node": _gen_node,
    "node-static": _gen_node_static,
    "python": _gen_python,
    "go": _gen_go,
    "java-maven": _gen_java_maven,
    "static": _gen_static,
    "generic": _gen_generic,
}


# ---------------------------------------------------------------------------
# Small formatting helpers
# ---------------------------------------------------------------------------


def _exec_form(instruction: str, args: list) -> str:
    """Render ENTRYPOINT/CMD in exec (JSON array) form."""
    rendered = ", ".join(f'"{a}"' for a in args)
    return f"{instruction} [{rendered}]"


def _join_extra(cfg: DockerfileConfig) -> str:
    """Append extra build commands onto an existing RUN line via ``&&``."""
    if not cfg.extra_build_commands:
        return ""
    return " && \\\n    " + " && \\\n    ".join(cfg.extra_build_commands)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def generate_dockerfile(config: Optional[DockerfileConfig] = None, **kwargs) -> str:
    """Generate a Code Engine-compatible Dockerfile as text.

    Pass either a :class:`DockerfileConfig`, or keyword arguments that are forwarded
    to :class:`DockerfileConfig`. Returns the Dockerfile contents as a string.

    Example::

        text = generate_dockerfile(runtime="python", python_module="app:app",
                                   install_packages=["gcc"])
    """
    cfg = config or DockerfileConfig(**kwargs)
    cfg.validate()

    header = [
        "# syntax=docker/dockerfile:1",
        "# Generated for IBM Cloud Code Engine "
        f"(runtime: {cfg.runtime}, port: {cfg.port}, non-root: {cfg.non_root}).",
        "# Best practices: multi-stage build, tiny base image, single-layer installs,",
        "# non-root USER, EXPOSE 8080, WORKDIR /app.",
        "",
    ]
    body = _GENERATORS[cfg.runtime](cfg)
    text = "\n".join(header + body).rstrip() + "\n"
    return text


def _sanitize_image_name(image_name: str) -> str:
    """Turn an image reference into a safe filename stem.

    ``memgraph/memgraph-mage:latest`` -> ``memgraph_memgraph-mage``
    """
    stem = image_name.split("@", 1)[0]  # drop digest
    stem = (
        stem.rsplit(":", 1)[0] if ":" in stem.rsplit("/", 1)[-1] else stem
    )  # drop tag
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", stem).strip("_")
    return stem or "image"


def save_dockerfile(
    image_name: str,
    directory: Optional[str] = None,
    config: Optional[DockerfileConfig] = None,
    *,
    overwrite: bool = False,
    prefix_namespace: bool = False,
    **kwargs,
) -> str:
    """Generate a Dockerfile and write it to ``<directory>/<imagename>_Dockerfile``.

    Args:
        image_name: Used for the filename stem (slashes/colons are sanitized).
        directory: Target directory (created if missing). Falls back to
            ``$CODE_ENGINE_DOCKERFILE_DIR``, then the current working directory.
        config: Optional :class:`DockerfileConfig`; otherwise built from ``kwargs``.
        overwrite: If False (default), refuses to clobber an existing file.
        prefix_namespace: If True, prepend ``$CONTAINER_REGISTRY_NAMESPACE`` (when set)
            to the filename stem, e.g. ``<namespace>_<imagename>_Dockerfile``.

    Returns:
        The absolute path to the written file.
    """
    text = generate_dockerfile(config, **kwargs)
    directory = directory or _env(ENV_DOCKERFILE_OUTPUT_DIR) or os.getcwd()
    os.makedirs(directory, exist_ok=True)

    stem = _sanitize_image_name(image_name)
    if prefix_namespace:
        namespace = _env(ENV_CR_NAMESPACE)
        if namespace:
            stem = f"{_sanitize_image_name(namespace)}_{stem}"

    path = os.path.join(directory, f"{stem}_Dockerfile")
    if os.path.exists(path) and not overwrite:
        raise FileExistsError(
            f"{path} already exists. Pass overwrite=True to replace it."
        )
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return os.path.abspath(path)

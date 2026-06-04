"""Create Software Hub custom cards linking to service instance routes.

Reads the route URLs that the ``5_prep_*`` scripts in
``src/scripts/5_component_specific_scripts/`` export into
``cp4d_config/cpd_instance_details.sh``, then creates one ``list`` custom card
per service (MongoDB Ops Manager, DataStax Mission Control, OpenSearch) whose
rows link to each instance's routes.

The card definitions are built by the templates in
``custom_card_templates``; this module is the glue that supplies live URLs and
calls the Custom cards API via ``SoftwareHubCustomCardManager``.

Authentication uses the CPD admin credentials that
``3.3.1_get_instance_creds.sh`` writes to the same vars file
(``CPD_URL``, ``CPD_USERNAME``, ``CPD_APIKEY``).

Usage:
    python build_instance_route_cards.py [path/to/cpd_instance_details.sh]

If no path is given, the file is located relative to the repo root.
"""

import os
import re
import sys

from softwarehub_custom_card_helpers import (
    SoftwareHubCustomCardManager,
    SoftwareHubCustomCardError,
)
from custom_card_templates import (
    build_mongodb_instances_card,
    build_datastax_instances_card,
    build_opensearch_instances_card,
)


# Matches: export NAME="value"  /  export NAME='value'  /  export NAME=value
_EXPORT_RE = re.compile(
    r'^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)=(?:"([^"]*)"|\'([^\']*)\'|(\S*))'
)


def parse_exports(vars_file):
    """Parse ``export VAR=value`` lines, keeping every occurrence in order.

    The prep scripts append a fresh block per instance, re-exporting the same
    variable name. Sourcing the file would collapse those to the last value,
    so we parse it ourselves and return a list of values per name.

    Returns:
        dict[str, list[str]]: variable name -> values in file order.
    """
    exports = {}
    with open(vars_file, "r", encoding="utf-8") as fh:
        for line in fh:
            match = _EXPORT_RE.match(line)
            if not match:
                continue
            name = match.group(1)
            value = next(
                (g for g in match.groups()[1:] if g is not None), ""
            )
            exports.setdefault(name, []).append(value)
    return exports


def _nonempty(values):
    """Return the list with blank entries removed."""
    return [v for v in values if v]


def _default_vars_file():
    """Locate cp4d_config/cpd_instance_details.sh relative to this file."""
    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = here
    while repo_root != "/" and not os.path.exists(
        os.path.join(repo_root, "pyproject.toml")
    ):
        repo_root = os.path.dirname(repo_root)
    return os.path.join(repo_root, "cp4d_config", "cpd_instance_details.sh")


def build_card_definitions(manager, exports):
    """Build card definitions for any services that have route URLs.

    Args:
        manager: SoftwareHubCustomCardManager instance.
        exports: dict[str, list[str]] from parse_exports.

    Returns:
        list[dict]: card definitions ready for create_or_replace_card(**defn).
    """
    definitions = []

    # --- MongoDB: one MONGODB_OPS_URL block per instance ---
    mongo_urls = _nonempty(exports.get("MONGODB_OPS_URL", []))
    if mongo_urls:
        instances = [
            {"name": f"MongoDB instance {i}", "ops_url": url}
            for i, url in enumerate(mongo_urls, start=1)
        ]
        # Single instance: drop the index from the label.
        if len(instances) == 1:
            instances[0]["name"] = "MongoDB Ops Manager"
        definitions.append(build_mongodb_instances_card(manager, instances))

    # --- DataStax: MC UI URL + HCD DataAPI endpoint (primary DC) ---
    mc_urls = _nonempty(exports.get("DATASTAX_MC_URL", []))
    hcd_urls = _nonempty(exports.get("DATASTAX_HCD_ENDPOINT", []))
    if mc_urls or hcd_urls:
        definitions.append(
            build_datastax_instances_card(
                manager,
                mc_url=mc_urls[-1] if mc_urls else None,
                hcd_endpoint=hcd_urls[-1] if hcd_urls else None,
            )
        )

    # --- OpenSearch: backend + dashboards URL per instance ---
    backend_urls = _nonempty(exports.get("OSEARCH_URL", []))
    dashboards_urls = _nonempty(exports.get("OSEARCH_DASHBOARDS_URL", []))
    if backend_urls or dashboards_urls:
        count = max(len(backend_urls), len(dashboards_urls))
        instances = []
        for i in range(count):
            backend = backend_urls[i] if i < len(backend_urls) else None
            dashboards = dashboards_urls[i] if i < len(dashboards_urls) else None
            name = "OpenSearch" if count == 1 else f"OpenSearch instance {i + 1}"
            instances.append(
                {
                    "name": name,
                    "backend_url": backend,
                    "dashboards_url": dashboards,
                }
            )
        definitions.append(build_opensearch_instances_card(manager, instances))

    return definitions


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    vars_file = argv[0] if argv else _default_vars_file()

    if not os.path.exists(vars_file):
        print(f"[ERROR] vars file not found: {vars_file}", file=sys.stderr)
        return 1

    exports = parse_exports(vars_file)

    # CPD admin credentials (written by 3.3.1_get_instance_creds.sh).
    try:
        cpd_url = _nonempty(exports["CPD_URL"])[-1]
        cpd_username = _nonempty(exports["CPD_USERNAME"])[-1]
        cpd_apikey = _nonempty(exports["CPD_APIKEY"])[-1]
    except (KeyError, IndexError):
        print(
            "[ERROR] CPD_URL / CPD_USERNAME / CPD_APIKEY not found in "
            f"{vars_file}. Run 3.3.1_get_instance_creds.sh first.",
            file=sys.stderr,
        )
        return 1

    # CPD clusters typically present a self-signed cert; allow opt-out via env.
    verify = os.environ.get("CPD_VERIFY_TLS", "false").lower() in (
        "1", "true", "yes",
    )

    manager = SoftwareHubCustomCardManager(
        cpd_cluster_host=cpd_url,
        username=cpd_username,
        api_key=cpd_apikey,
        verify=verify,
    )

    definitions = build_card_definitions(manager, exports)
    if not definitions:
        print(
            "[WARN] No MongoDB / DataStax / OpenSearch route URLs found in "
            f"{vars_file}. Nothing to create."
        )
        return 0

    exit_code = 0
    for defn in definitions:
        defn = {k: v for k, v in defn.items() if v is not None}
        key = defn["key"]

        rows = (defn.get("data") or {}).get("list_data", {}).get("rows", [])

        # Print exactly what this card is set up with before creating it, so the
        # install log shows each card's contents (title, order, and every row /
        # link), not just an [OK] line.
        print(f"--- Custom card: {key} ---")
        print(f"    title:         {defn.get('title')}")
        print(f"    template_type: {defn.get('template_type')}")
        print(f"    order:         {defn.get('order')}")
        print(f"    permissions:   {defn.get('permissions')}")
        if defn.get("description"):
            print(f"    description:   {defn['description']}")
        if rows:
            print(f"    rows ({len(rows)}):")
            for row in rows:
                url = row.get("drilldown_url", "")
                # Row cells are the non-link key/values; the link is drilldown_url.
                cells = ", ".join(
                    f"{k}={v}"
                    for k, v in row.items()
                    if k not in ("drilldown_url", "window_open_target")
                )
                print(f"      - {cells} -> {url}")
        else:
            # A list card with no rows renders empty in Software Hub - flag it
            # rather than silently pushing an empty card.
            print("    rows: NONE - skipping (would render an empty card).")
            print("")
            continue

        try:
            # Delete any existing card with this key first so a stale or
            # previously-empty definition (which Software Hub may keep rendering
            # from cache) is fully cleared before we recreate it. A missing card
            # returns 404 - that's fine, nothing to delete.
            try:
                manager.delete_card(key)
                print(f"    [INFO] Removed existing card '{key}' before recreate.")
            except SoftwareHubCustomCardError as del_err:
                if del_err.status_code not in (404, None):
                    raise

            # PUT (re)creates the card with the fresh definition above.
            manager.create_or_replace_card(**defn)
            print(f"    [OK] Created/replaced custom card '{key}'.")
        except SoftwareHubCustomCardError as err:
            print(f"    [ERROR] Failed to create card '{key}': {err}", file=sys.stderr)
            exit_code = 1
        print("")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())

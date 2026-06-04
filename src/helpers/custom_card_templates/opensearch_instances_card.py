"""Card template: OpenSearch instances.

Builds a ``list`` custom card whose rows link to the OpenSearch backend
(REST API, port 9200) and the OpenSearch Dashboards (port 5601). These URLs
are produced by
``src/scripts/5_component_specific_scripts/5_prep_wxd_opensearch.sh``, which
exports ``OSEARCH_URL`` (backend) and ``OSEARCH_DASHBOARDS_URL`` (dashboards)
into ``cp4d_config/cpd_instance_details.sh``.

The prep script creates ``<instance>-backend`` and ``<instance>-dashboards``
passthrough routes per OpenSearch cluster, but only writes the primary
cluster's URLs to the vars file. Pass the collected URLs (and optional
instance labels) here; the builder emits one row per available route.
"""

CARD_KEY = "opensearch_instances"
CARD_TITLE = "OpenSearch"
CARD_DESCRIPTION = (
    "Links to the OpenSearch REST endpoint and Dashboards for each instance."
)

HEADERS = ["Instance", "Endpoint", "Link"]


def build_opensearch_instances_card(
    manager,
    instances,
    order=3,
    permissions=None,
    roles=None,
    window_open_target="_blank",
):
    """Build the OpenSearch instances card definition.

    Args:
        manager: A SoftwareHubCustomCardManager (used for its build_list_data).
        instances: Iterable of dicts, one per OpenSearch cluster, each with:
            - "name": instance label shown in the rows.
            - "backend_url": REST endpoint URL (OSEARCH_URL).
            - "dashboards_url": Dashboards URL (OSEARCH_DASHBOARDS_URL).
        order: Card position on the home page (1-50).
        permissions: List of Software Hub permissions; defaults to
            ["manage_catalog"] (administrator).
        roles: Optional list of authorized roles.
        window_open_target: Optional target window for navigation.

    Returns:
        dict: kwargs ready to splat into manager.create_or_replace_card(...).
    """
    rows = []
    for inst in instances:
        name = inst.get("name", "OpenSearch")
        backend = inst.get("backend_url")
        dashboards = inst.get("dashboards_url")
        if backend:
            rows.append(
                {
                    "Instance": name,
                    "Endpoint": "REST API (9200)",
                    "Link": "Open endpoint",
                    "drilldown_url": backend,
                    "window_open_target": "_blank",
                }
            )
        if dashboards:
            rows.append(
                {
                    "Instance": name,
                    "Endpoint": "Dashboards (5601)",
                    "Link": "Open Dashboards",
                    "drilldown_url": dashboards,
                    "window_open_target": "_blank",
                }
            )

    data = manager.build_list_data(rows=rows, headers=HEADERS)

    return {
        "key": CARD_KEY,
        "title": CARD_TITLE,
        "template_type": "list",
        "description": CARD_DESCRIPTION,
        "order": order,
        "permissions": list(permissions) if permissions else ["manage_catalog"],
        "roles": list(roles) if roles else None,
        "data": data,
        "window_open_target": window_open_target,
    }

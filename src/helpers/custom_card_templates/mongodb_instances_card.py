"""Card template: MongoDB Ops Manager instances.

Builds a ``list`` custom card whose rows link to the Ops Manager UI of each
MongoDB instance. The route URL is produced by
``src/scripts/5_component_specific_scripts/5_prep_mongodb.sh``, which exports
``MONGODB_OPS_URL`` into ``cp4d_config/cpd_instance_details.sh``.

The prep script writes one ``MONGODB_OPS_URL`` block per CPDMongoDBOpsManager
instance. Pass the collected URLs (and optional instance labels) here.
"""

CARD_KEY = "mongodb_ops_manager_instances"
CARD_TITLE = "MongoDB Ops Manager"
CARD_DESCRIPTION = "Links to the Ops Manager console for each MongoDB instance."

# Headers for the list table.
HEADERS = ["Instance", "Console"]


def build_mongodb_instances_card(
    manager,
    instances,
    order=2,
    permissions=None,
    roles=None,
    window_open_target="_blank",
):
    """Build the MongoDB Ops Manager instances card definition.

    Args:
        manager: A SoftwareHubCustomCardManager (used for its build_list_data).
        instances: Iterable of dicts, one per MongoDB instance, each with:
            - "name": instance label shown in the row (e.g. "mongodb-cpd").
            - "ops_url": the Ops Manager URL (MONGODB_OPS_URL).
        order: Card position on the home page (1-50).
        permissions: List of Software Hub permissions; defaults to
            ["manage_catalog"] (administrator).
        roles: Optional list of authorized roles.
        window_open_target: Optional target window for navigation.s

    Returns:
        dict: kwargs ready to splat into manager.create_or_replace_card(...).
    """
    rows = []
    for inst in instances:
        url = inst.get("ops_url")
        if not url:
            continue
        rows.append(
            {
                "Instance": inst.get("name", "MongoDB"),
                "Console": "Open Ops Manager",
                "drilldown_url": url,
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

"""Card template: DataStax Mission Control instances.

Builds a ``list`` custom card whose rows link to the DataStax Mission Control
UI and the HCD DataAPI endpoint. These URLs are produced by
``src/scripts/5_component_specific_scripts/5_prep_datastax_mc.sh``, which
exports ``DATASTAX_MC_URL`` (Mission Control UI) and ``DATASTAX_HCD_ENDPOINT``
(DataAPI route) into ``cp4d_config/cpd_instance_details.sh``.

Unlike MongoDB/OpenSearch, the prep script writes a single MC URL plus one
DataAPI endpoint (for the primary CassandraDatacenter), so this card builds
one row per discovered route rather than per instance.
"""

CARD_KEY = "datastax_mc_instances"
CARD_TITLE = "DataStax Mission Control"
CARD_DESCRIPTION = "Links to the Mission Control console and the HCD DataAPI endpoint."

HEADERS = ["Endpoint", "Link"]


def build_datastax_instances_card(
    manager,
    mc_url=None,
    hcd_endpoint=None,
    order=1,
    permissions=None,
    roles=None,
    window_open_target="_blank",
):
    """Build the DataStax Mission Control instances card definition.

    Args:
        manager: A SoftwareHubCustomCardManager (used for its build_list_data).
        mc_url: Mission Control UI URL (DATASTAX_MC_URL).
        hcd_endpoint: HCD DataAPI endpoint URL (DATASTAX_HCD_ENDPOINT).
        order: Card position on the home page (1-50).
        permissions: List of Software Hub permissions; defaults to
            ["manage_catalog"] (administrator).
        roles: Optional list of authorized roles.
        window_open_target: Optional target window for navigation.

    Returns:
        dict: kwargs ready to splat into manager.create_or_replace_card(...).
    """
    rows = []
    if mc_url:
        rows.append(
            {
                "Endpoint": "Mission Control console",
                "Link": "Open console",
                "drilldown_url": mc_url,
                "window_open_target": "_blank",
            }
        )
    if hcd_endpoint:
        rows.append(
            {
                "Endpoint": "HCD DataAPI",
                "Link": "Open DataAPI",
                "drilldown_url": hcd_endpoint,
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

"""Custom card templates for Software Hub instance/route cards.

Each module here builds the ``data`` payload and card metadata for a single
service's instances, ready to pass to
``SoftwareHubCustomCardManager.create_or_replace_card``.

The route URLs are not hardcoded - they are read at build time from the
environment variables that the ``5_prep_*`` scripts in
``src/scripts/5_component_specific_scripts/`` export into
``cp4d_config/cpd_instance_details.sh``.
"""

from .mongodb_instances_card import build_mongodb_instances_card
from .datastax_instances_card import build_datastax_instances_card
from .opensearch_instances_card import build_opensearch_instances_card

__all__ = [
    "build_mongodb_instances_card",
    "build_datastax_instances_card",
    "build_opensearch_instances_card",
]

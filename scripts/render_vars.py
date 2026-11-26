"""Discover SFS Turbo file systems by tag and render the dashboard variables file.

This script queries SFS Turbo file systems that carry a given tag, then renders
the Jinja2 variable template into a JSON file consumed by render_template.py.

Usage:
    python3 render_vars.py \
        --tag-key Application --tag-value dash-demo \
        --template dashboards.vars.jinja \
        --rendered-file examples/complete/dashboards.vars.json

Credentials are read from the HW_ACCESS_KEY / HW_SECRET_KEY environment
variables when the script is invoked.
"""

import argparse
import os

from huaweicloudsdkcore.auth.credentials import BasicCredentials
from huaweicloudsdksfsturbo.v1 import SFSTurboClient
from huaweicloudsdksfsturbo.v1.region.sfsturbo_region import SFSTurboRegion
from huaweicloudsdksfsturbo.v1.model import (
    ListSharesByTagRequest,
    ListSharesByTagRequestBody,
    Tag,
)

import render_template


def get_args():
    arg_parser = argparse.ArgumentParser(
        description="Discover SFS Turbo file systems by tag and render vars"
    )
    arg_parser.add_argument(
        "--tag-key",
        required=True,
        type=str,
        action="store",
        help="Tag key used to search for file systems, e.g. Application",
    )
    arg_parser.add_argument(
        "--tag-value",
        required=True,
        type=str,
        action="store",
        help="Tag value used to search for file systems, e.g. dash-demo",
    )
    arg_parser.add_argument(
        "--template",
        required=True,
        type=str,
        action="store",
        help="Filename of the template in the templates/ directory (e.g. dashboards.vars.jinja)",
    )
    arg_parser.add_argument(
        "--rendered-file",
        required=True,
        type=str,
        action="store",
        help="Complete path and filename for the rendered output (e.g. dashboards.vars.json)",
    )
    arg_parser.add_argument(
        "--region",
        required=False,
        type=str,
        action="store",
        default=os.environ.get("HW_REGION_NAME", "cn-north-4"),
        help="Region to query (default: HW_REGION_NAME or cn-north-4)",
    )
    return arg_parser.parse_args()


def build_client(region):
    ak = os.environ.get("HW_ACCESS_KEY")
    sk = os.environ.get("HW_SECRET_KEY")
    if not ak or not sk:
        raise SystemExit(
            "Missing credentials: set HW_ACCESS_KEY and HW_SECRET_KEY "
            "(获取方式：华为云『我的凭证』页面创建访问密钥)"
        )
    credentials = BasicCredentials(ak, sk)
    region_obj = getattr(SFSTurboRegion, region.upper().replace("-", "_"))
    return SFSTurboClient.new_builder() \
        .with_credentials(credentials) \
        .with_region(region_obj) \
        .build()


def list_shares_by_tag(client, tag_key, tag_value):
    request = ListSharesByTagRequest(
        body=ListSharesByTagRequestBody(
            action="filter",
            limit="100",
            offset="0",
            tags=[Tag(key=tag_key, values=[tag_value])],
        )
    )
    response = client.list_shares_by_tag(request)
    resources = getattr(response, "resources", []) or []
    results = []
    for res in resources:
        results.append(
            {
                "file_system_id": res.resource_id,
                "name": res.resource_name,
            }
        )
    results.sort(key=lambda x: x["name"] or "")
    return results


def get_widget_width(resources):
    count = len(resources)
    if count > 0:
        return max(6, 24 // count)
    return 24


def main():
    args = get_args()
    client = build_client(args.region)
    file_systems = list_shares_by_tag(client, args.tag_key, args.tag_value)
    widget_width = get_widget_width(file_systems)
    results_dict = {
        "region": args.region,
        "tag_key": args.tag_key,
        "tag_value": args.tag_value,
        "sfs": {"sfs_fs": file_systems, "widget_width": widget_width},
    }
    render_template.render_template(
        template=args.template,
        template_vars=results_dict,
        rendered_file=args.rendered_file,
    )


if __name__ == "__main__":
    main()
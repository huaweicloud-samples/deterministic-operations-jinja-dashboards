"""Render a Jinja2 template into a file.

Usage:
    python3 render_template.py \
        --template dashboards.tf.jinja \
        --template-vars dashboards.vars.json \
        --rendered-file dashboards.tf
"""

import argparse
import json
import os

from jinja2 import Environment, FileSystemLoader, select_autoescape


def get_args():
    arg_parser = argparse.ArgumentParser(
        description="Render a Jinja2 template to a target file"
    )
    arg_parser.add_argument(
        "--template",
        required=True,
        type=str,
        action="store",
        help="Filename of the template in the templates/ directory to render",
    )
    arg_parser.add_argument(
        "--template-vars",
        required=True,
        type=str,
        action="store",
        help="Path to JSON file containing the variables used by the template",
    )
    arg_parser.add_argument(
        "--rendered-file",
        required=True,
        type=str,
        action="store",
        help="Complete path and filename for the rendered output file",
    )
    return arg_parser.parse_args()


def render_template(template, template_vars, rendered_file):
    environment = Environment(
        loader=FileSystemLoader(["./templates/"]),
        autoescape=select_autoescape(),
    )
    template = environment.get_template(template)
    body = template.render(template_vars=template_vars)
    out_dir = os.path.dirname(rendered_file)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(rendered_file, mode="w", encoding="utf-8") as message:
        message.write(body)


def main():
    args = get_args()
    with open(args.template_vars) as f:
        template_vars = json.loads(f.read())
    render_template(
        template=args.template,
        template_vars=template_vars,
        rendered_file=args.rendered_file,
    )


if __name__ == "__main__":
    main()
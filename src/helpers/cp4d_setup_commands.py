import marimo

__generated_with = "0.23.5"
app = marimo.App(width="full")

with app.setup:
    import marimo as mo
    import requests
    import jinja2
    import click
    import json
    import sys
    import os
    import re

    from dotenv import load_dotenv
    from moterm import Kmd
    from jinja2 import meta

    load_dotenv("freshcluster.env", override=True)


@app.cell
def _():
    return


@app.cell
def _():
    cpd_cli_login_cmd = (
        "cpd-cli manage login-to-ocp ${SERVER_ARGUMENTS} ${LOGIN_ARGUMENTS}"
    )
    print(cpd_cli_login_cmd)
    add_global_pull_secret_cmd = "cpd-cli manage add-icr-cred-to-global-pull-secret \
    --entitled_registry_key=${IBM_ENTITLEMENT_KEY}"
    print(add_global_pull_secret_cmd)
    return add_global_pull_secret_cmd, cpd_cli_login_cmd


@app.cell
def _():
    trigger = mo.ui.run_button(label="apply entitlement key")
    trigger
    return (trigger,)


@app.cell
def _(add_global_pull_secret_cmd, cpd_cli_login_cmd, trigger):
    if trigger.value:
        cpd_cli_login_run = Kmd(command=validate_template(cpd_cli_login_cmd), width=100)
        add_global_pull_secret_run = Kmd(
            command=validate_template(add_global_pull_secret_cmd), width=100
        )
    else:
        cpd_cli_login_run = add_global_pull_secret_run = None

    mo.hstack(
        [cpd_cli_login_run, add_global_pull_secret_run],
        widths=[0.4, 0.4],
        justify="space-around",
    )
    return


@app.cell
def _():
    # validate_template(add_global_pull_secret_cmd)
    return


@app.function
def validate_template(template_str, input_data=None, full_output=False):
    """
    Validates a template string with various variable formats: {{}}, {}, ${}

    Args:
        template_str (str): Template string with variables
        input_data (dict): Additional data to validate template against
        full_output (bool): If True, returns full validation details. If False, returns only rendered output.

    Returns:
        str or dict: Rendered template string by default, or full validation results if full_output=True
    """
    if input_data is None:
        input_data = {}

    try:
        # Convert ${var} format to {{var}} format
        normalized_template = re.sub(r"\$\{([^}]+)\}", r"{{\1}}", template_str)

        # Convert {var} format to {{var}} format, but avoid double conversion
        # Only convert single braces that aren't already double braces
        normalized_template = re.sub(
            r"(?<!\{)\{([^{}]+)\}(?!\})", r"{{\1}}", normalized_template
        )

        # Create Jinja2 environment
        env = jinja2.Environment()
        template = env.from_string(normalized_template)

        # Extract variables from template
        ast = env.parse(normalized_template)
        variables = meta.find_undeclared_variables(ast)

        # Automatically detect environment variables and merge with input_data
        combined_data = {}
        for var in variables:
            if var in os.environ:
                combined_data[var] = os.environ[var]

        # Override with any provided input_data
        combined_data.update(input_data)

        # Check if all required variables are provided
        missing_vars = variables - set(combined_data.keys())

        # Render template
        rendered = template.render(combined_data)

        if full_output:
            return {
                "success": True,
                "rendered": rendered,
                "variables_found": list(variables),
                "missing_variables": list(missing_vars),
                "original_template": template_str,
                "normalized_template": normalized_template,
            }
        else:
            return rendered

    except Exception as e:
        if full_output:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "original_template": template_str,
                "variables_found": [],
                "missing_variables": [],
            }
        else:
            raise e


@app.cell
def _():
    return


@app.cell
def _():
    return


@app.cell
def _():
    return


@app.cell
def _():
    return


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()

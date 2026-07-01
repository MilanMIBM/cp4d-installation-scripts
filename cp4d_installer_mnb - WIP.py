import marimo

__generated_with = "0.23.5"
app = marimo.App(width="full")


@app.cell
def _():
    import marimo as mo
    import requests
    import click
    import json
    import sys
    import os
    import re

    from dotenv import load_dotenv
    from moterm import Kmd

    return Kmd, load_dotenv, os


@app.cell
def _(load_dotenv):
    load_dotenv(".env", override=True)
    return


@app.cell
def _(os):
    IBM_ENTITLEMENT_KEY = os.getenv("IBM_ENTITLEMENT_KEY", "")
    PROJECT_CPD_INST_OPERATORS = os.getenv(
        "PROJECT_CPD_INST_OPERATORS", "cpd-operators"
    )
    PROJECT_CPD_INST_SCHEDULER = os.getenv(
        "PROJECT_CPD_INST_SCHEDULER", "ibm-scheduler"
    )
    PROJECT_CPD_INST_OPERANDS = os.getenv("PROJECT_CPD_INST_OPERANDS", "cpd-operands")
    CPD_VERSION = os.getenv("CPD_VERSION", "5.4.0")
    return


@app.cell
def _(os):
    OCP_TOKEN = os.getenv("OCP_TOKEN", "")
    OCP_USERNAME = os.getenv("OCP_USERNAME", "")
    OCP_PASSWORD = os.getenv("OCP_PASSWORD", "")
    OCP_URL = os.getenv("OCP_URL", "")
    return OCP_PASSWORD, OCP_URL, OCP_USERNAME


@app.cell
def _(OCP_PASSWORD, OCP_URL, OCP_USERNAME):
    IMAGE_ARCH = "amd64"
    SERVER_ARGUMENTS = f"--server={OCP_URL}"
    LOGIN_ARGUMENTS = f"--username={OCP_USERNAME} --password={OCP_PASSWORD}"
    CPDM_OC_LOGIN = f"cpd-cli manage login-to-ocp {SERVER_ARGUMENTS} {LOGIN_ARGUMENTS}"
    OC_LOGIN = f"oc login {SERVER_ARGUMENTS} {LOGIN_ARGUMENTS}"
    return (CPDM_OC_LOGIN,)


@app.cell
def _(CPDM_OC_LOGIN, Kmd):
    login_command = Kmd(command=CPDM_OC_LOGIN, width=100)
    login_command
    return


@app.cell
def _():
    test_command = """
    if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

    set -euo pipefail

    SECONDS=0
    trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

    export CPD_CLI_MANAGE_WORKSPACE="$HOME/cpd-cli"
    export PATH="$HOME/cpd-cli:$PATH"

    [ -f .env ] && source ./cpd_vars.sh

    PROJECT_CPD_INST_OPERATORS=${PROJECT_CPD_INST_OPERATORS:-cpd-operators}
    PROJECT_CPD_INST_OPERANDS=${PROJECT_CPD_INST_OPERANDS:-cpd-operands}
    """
    return (test_command,)


@app.cell
def _(Kmd, test_command):
    test_cmd = Kmd(command=test_command)
    return (test_cmd,)


@app.cell
def _(test_cmd):
    test_cmd
    return


if __name__ == "__main__":
    app.run()

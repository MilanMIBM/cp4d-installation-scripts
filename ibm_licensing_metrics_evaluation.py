import marimo

__generated_with = "0.23.8"
app = marimo.App(width="full")

with app.setup:
    import marimo as mo
    import pandas as pd
    from src.helpers.ibm_licensing_operator_helpers import (
        IBMLicensingClient,
        load_config_env,
    )
    from dotenv import load_dotenv

    load_dotenv(".env")

    import warnings
    import requests
    import json
    import sys
    import os
    import re


@app.cell
def _():
    warnings.filterwarnings("ignore", message="Unverified HTTPS request")
    ibm_licensing_client = IBMLicensingClient(
        env=load_config_env(), as_dataframe=True
    )
    return (ibm_licensing_client,)


@app.cell
def _(ibm_licensing_client):
    product_metrics = ibm_licensing_client.products()
    product_metrics
    return


@app.cell
def _(ibm_licensing_client):
    services_metrics = ibm_licensing_client.services()
    services_metrics
    return


@app.cell
def _(ibm_licensing_client):
    bundled_product_metrics = ibm_licensing_client.bundled_products()
    bundled_product_metrics
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

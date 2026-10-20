#!/usr/bin/env python3
"""Trigger an HCP Terraform run and wait for its plan to finish."""

import json
import os
import sys
import time
import urllib.error
import urllib.request


TERMINAL_STATES = {
    "planned",
    "planned_and_finished",
    "errored",
    "canceled",
    "discarded",
    "force_canceled",
}

SUCCESS_STATES = {"planned", "planned_and_finished"}


class HCPTerraformError(RuntimeError):
    """Raised when an HCP Terraform API operation fails."""


def api_request(host, token, path, method="GET", payload=None):
    """Send a request to the HCP Terraform API."""
    body = json.dumps(payload).encode("utf-8") if payload is not None else None

    request = urllib.request.Request(
        f"https://{host}/api/v2{path}",
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/vnd.api+json",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        # Do not print request headers or the API token.
        details = exc.read().decode("utf-8", errors="replace")
        raise HCPTerraformError(
            f"HCP Terraform API returned HTTP {exc.code}: {details}"
        ) from exc
    except urllib.error.URLError as exc:
        raise HCPTerraformError(
            f"Could not reach HCP Terraform API: {exc.reason}"
        ) from exc


def main():
    token = os.environ.get("TF_API_TOKEN")
    workspace_id = os.environ.get("TF_WORKSPACE_ID")
    organization = os.environ.get("TF_ORGANIZATION")
    host = os.environ.get("TF_HOSTNAME", "app.terraform.io")
    commit_sha = os.environ.get("GITHUB_SHA", "local-run")

    if not token or not workspace_id or not organization:
        raise HCPTerraformError(
            "Set TF_API_TOKEN, TF_WORKSPACE_ID, and TF_ORGANIZATION."
        )

    workspace_response = api_request(
        host, token, f"/workspaces/{workspace_id}"
    )
    workspace = workspace_response["data"]
    workspace_org_id = (
        workspace.get("relationships", {})
        .get("organization", {})
        .get("data", {})
        .get("id")
    )

    if workspace_org_id != organization:
        raise HCPTerraformError(
            "Workspace organization does not match TF_ORGANIZATION. "
            "Check whether TF_ORGANIZATION contains the organization name "
            "or ID expected by the API response."
        )

    payload = {
        "data": {
            "type": "runs",
            "attributes": {
                "message": f"GitHub Actions commit {commit_sha}",
                "is-destroy": False,
                "auto-apply": False,
            },
            "relationships": {
                "workspace": {
                    "data": {
                        "type": "workspaces",
                        "id": workspace_id,
                    }
                }
            },
        }
    }

    response = api_request(
        host, token, "/runs", method="POST", payload=payload
    )
    run_id = response["data"]["id"]

    print(f"Created HCP Terraform run: {run_id}")
    print("Waiting for the plan to finish...")

    for _ in range(120):
        run = api_request(host, token, f"/runs/{run_id}")["data"]
        status = run["attributes"]["status"]
        print(f"Current HCP Terraform status: {status}")

        if status in TERMINAL_STATES:
            if status not in SUCCESS_STATES:
                raise HCPTerraformError(
                    f"HCP Terraform plan did not succeed: {status}. "
                    f"Review run {run_id} in the HCP Terraform workspace."
                )

            print("HCP Terraform plan completed successfully.")
            print(
                "Review the run in HCP Terraform before manually approving "
                "any apply."
            )
            print(
                f"Run URL: https://{host}/app/{organization}/workspaces/"
                f"{workspace_id}/runs/{run_id}"
            )
            return 0

        time.sleep(10)

    raise HCPTerraformError(
        f"Timed out waiting for HCP Terraform run {run_id}. "
        "Check the run in HCP Terraform before retrying."
    )


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (HCPTerraformError, KeyError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)

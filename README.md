# AWS Production Data Engineering Platform

Terraform-managed AWS data platform portfolio project demonstrating
serverless ingestion, S3 data-lake storage, DynamoDB ingestion metadata,
Glue ETL/cataloging, Athena analytics, GitHub Actions CI, and HCP
Terraform planning.

> **Status:** The latest HCP Terraform plan
> succeeded and was reported as **36 to add, 0 to change, 0 to
> destroy**. The plan's resource list still needs review and it has not
> yet been confirmed/applied. Deployment and post-rebuild verification
> are therefore pending.
>
> The pipeline was previously tested end to end before the clean
> infrastructure rebuild. Historical test results: two JSON batches with
> three records each; Athena returned six rows and six distinct event
> IDs; purchases totaled INR 1,301.23 and refunds INR 125.00; DynamoDB
> showed two successful batches with three records each. Repeat these
> checks after redeployment before treating them as current results.

## Goals

-   Provision infrastructure with reusable Terraform modules.
-   Ingest JSON event batches with AWS Lambda into S3.
-   Track batch metadata in DynamoDB.
-   Transform nested JSON to Parquet with AWS Glue.
-   Discover schema using the Glue Data Catalog crawler.
-   Query processed data using Athena.
-   Validate Terraform and Python code through GitHub Actions.
-   Use HCP Terraform for remote state/plans with manual apply approval.

This is a learning/portfolio project with production-minded goals; it is
not a claim of production readiness until security, reliability,
idempotency, recovery, and post-deployment testing are complete.

## Architecture

``` mermaid
flowchart TD
    A[Test event / JSON records] --> B[AWS Lambda ingestion]
    B --> C[S3 raw prefix]
    B --> D[DynamoDB batch metadata]
    C --> E[AWS Glue ETL]
    E --> F[S3 processed Parquet]
    F --> G[Glue crawler]
    G --> H[Glue Data Catalog]
    H --> I[Amazon Athena]
    I --> J[S3 query results]
    K[GitHub] --> L[GitHub Actions checks]
    K --> M[HCP Terraform plan]
    M --> N[AWS resources after approved apply]
```

## Technology stack

  Area                      Technology
  ------------------------- -----------------------------------------
  Cloud                     AWS
  Infrastructure as code    Terraform
  State and plan workflow   HCP Terraform
  CI                        GitHub Actions
  Ingestion                 Lambda, Python 3.12, Boto3
  Storage                   Amazon S3
  Batch metadata            DynamoDB
  ETL and schema            AWS Glue, PySpark, Glue Data Catalog
  SQL analytics             Amazon Athena
  Python tests/lint         pytest, Ruff
  Terraform lint            TFLint
  Security scan             Checkov evaluated; remediation deferred

## Repository layout

``` text
aws-production-data-platform/
├── .github/
│   ├── scripts/trigger_hcp_terraform_plan.py
│   └── workflows/terraform-ci.yml
├── applications/
│   ├── ingestion/lambda_function.py
│   ├── glue-jobs/transform.py
│   └── spark-jobs/                 # optional/planned
├── environments/dev/
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
├── modules/
│   ├── dynamodb/
│   ├── emr/                        # optional; keep disabled unless approved
│   ├── glue/
│   ├── iam/
│   ├── lambda/
│   ├── networking/
│   ├── redshift/                   # optional extension
│   └── s3-data-lake/
├── tests/test_lambda_ingestion.py
├── .gitignore
├── README.md
└── TROUBLESHOOTING.md
```

The exact repository contents may evolve. Never commit Terraform state,
`.terraform/`, credentials, API tokens, or sensitive `.tfvars` files.

## Data flow

1.  A test event supplies a `records` array to Lambda.
2.  Lambda validates the event and writes a JSON envelope under `raw/`.
3.  Lambda records batch status/count in DynamoDB.
4.  Glue reads raw JSON, expands `records`, selects/validates fields
    such as `event_id`, `event_type`, `amount`, and `currency`, and
    writes Parquet under `processed/`.
5.  The Glue crawler updates the Data Catalog.
6.  Athena queries the catalog table and writes results under the
    configured `athena-results/` S3 prefix.

S3 "folders" are key prefixes rather than directories that must be
created in advance.

### Example Lambda event

``` json
{
  "records": [
    {"event_id": "evt-001", "event_type": "purchase", "amount": 250.75, "currency": "INR"},
    {"event_id": "evt-002", "event_type": "refund", "amount": 50.00, "currency": "INR"},
    {"event_id": "evt-003", "event_type": "purchase", "amount": 499.99, "currency": "INR"}
  ]
}
```

For this single batch, expected totals are two purchases totaling INR
750.74 and one refund totaling INR 50.00. These values only apply when
querying that batch alone.

## Local validation

From the repository root:

``` bash
terraform fmt -recursive -check
terraform -chdir=environments/dev init
terraform -chdir=environments/dev validate
tflint --recursive
python -m ruff check .
python -m pytest -q
git diff --check
```

HCP Terraform is the intended remote state/execution workflow. Do not
add a local or S3 backend unless intentionally redesigning the state
setup.

## GitHub Actions and HCP Terraform

The GitHub Actions workflow runs code checks and calls
`.github/scripts/trigger_hcp_terraform_plan.py` for non-pull-request
events. The workflow uses these GitHub Actions secrets:

-   `TF_API_TOKEN`
-   `TF_WORKSPACE_ID`
-   `TF_ORGANIZATION`

It sets `TF_HOSTNAME` to `app.terraform.io`. Never print or commit token
values.

**Apply policy:** Keep auto-apply disabled. Review the workspace, AWS
account/region, every resource in the plan, cost implications, and
add/change/destroy counts before manually approving an apply. A
successful plan does not mean resources have been deployed.

Checkov remediation is deferred by decision. The earlier scan showed 148
passed and 17 failed checks. Removing Checkov from the active CI
dependency does not resolve those findings; revisit them in a separate
security-hardening task.

## Post-deployment test checklist

1.  Invoke Lambda and confirm success.
2.  Confirm JSON under the expected S3 `raw/` prefix.
3.  Confirm DynamoDB batch metadata and record count.
4.  Run Glue and confirm `SUCCEEDED`.
5.  Confirm Parquet objects under the configured processed prefix.
6.  Run the crawler and confirm the catalog table location matches the
    processed prefix.
7.  Run Athena queries and validate row counts, event IDs, totals, and
    duplicates.
8.  Test reruns/retries to ensure they do not create unintended
    duplicates.

Example Athena queries (replace placeholders with the actual
database/table names):

``` sql
SELECT * FROM "your_catalog_database"."your_table_name" LIMIT 10;
```

``` sql
SELECT event_type, COUNT(*) AS event_count, SUM(amount) AS total_amount
FROM "your_catalog_database"."your_table_name"
GROUP BY event_type
ORDER BY event_type;
```

``` sql
SELECT event_id, COUNT(*) AS copies
FROM "your_catalog_database"."your_table_name"
GROUP BY event_id
HAVING COUNT(*) > 1;
```

Historical two-batch results were six rows/six distinct IDs, four
purchases totaling INR 1,301.23, and two refunds totaling INR 125.00.
Reconfirm after the rebuild.

## Optional extensions

-   **Amazon EMR/Spark:** Optional distributed processing for larger or
    more complex workloads; not required for the current Glue-to-Athena
    pipeline.
-   **Amazon Redshift:** Optional warehouse for modeled datasets and BI.
    Athena can query S3 directly, so Redshift is not required.

Keep these optional modules disabled unless the plan explicitly includes
them and the sandbox/cost implications are approved. Confirm the allowed
services and instance constraints before enabling either.

## Security and cost notes

-   Use a non-production account/region while learning.
-   Keep S3 Block Public Access and least-privilege IAM.
-   Never commit keys, tokens, Terraform state, `.terraform/`, or
    sensitive variable files.
-   Review Glue, Athena, DynamoDB point-in-time recovery, and compute
    charges.
-   Review plans before applying or destroying.
-   Do not claim KMS-based controls are enabled if the sandbox cannot
    use KMS.
-   Checkov findings are deferred, not resolved.

## Cleanup

Before destroying resources, review the HCP plan, account, region, and
all destroy actions. Preserve required data/logs. The S3 bucket uses
`force_destroy = false`, so objects and object versions may need
deliberate cleanup. Verify cleanup in AWS and HCP Terraform to avoid
residual charges.

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the project error log,
fixes, validation outcomes, and pending actions.

# AWS Production Data Engineering Platform

A hands-on AWS data engineering portfolio project that demonstrates
infrastructure as code, serverless ingestion, data lake storage, ETL
processing, metadata discovery, and SQL analytics.

> **Project status:** In progress. The Lambda ingestion, S3 raw storage,
> DynamoDB metadata, AWS Glue ETL, Glue Data Catalog crawler, and Athena
> query path have been exercised manually. Duplicate rows were observed
> in Athena during testing, and the pipeline is being reset and debugged
> before end-to-end validation is considered complete.

## Table of contents

-   [Overview](#overview)
-   [Architecture](#architecture)
-   [Technology stack](#technology-stack)
-   [Repository layout](#repository-layout)
-   [Data flow](#data-flow)
-   [Current implementation](#current-implementation)
-   [Prerequisites](#prerequisites)
-   [Deploying the development
    environment](#deploying-the-development-environment)
-   [Testing the pipeline](#testing-the-pipeline)
-   [Example Athena queries](#example-athena-queries)
-   [Configuration notes](#configuration-notes)
-   [Security and cost
    considerations](#security-and-cost-considerations)
-   [Known issues and next steps](#known-issues-and-next-steps)
-   [Planned roadmap](#planned-roadmap)
-   [Cleanup](#cleanup)

## Overview

The goal is to build a production-minded AWS data platform that can
ingest JSON event batches, retain raw data in Amazon S3, record
ingestion metadata in DynamoDB, transform records to Parquet with AWS
Glue, discover the schema through the Glue Data Catalog, and query the
processed dataset with Amazon Athena.

The project is managed with Terraform and HCP Terraform. GitHub Actions
provides continuous integration checks for Terraform configuration.

This is a learning and portfolio project, not yet a claim of production
readiness. Reliability, idempotency, automated integration testing,
least-privilege IAM, and operational documentation remain part of the
planned work.

## Architecture

``` mermaid
flowchart TD
    A[Manual or test event] --> B[AWS Lambda ingestion]
    B --> C[S3 raw JSON prefix]
    B --> D[DynamoDB ingestion metadata]
    C --> E[AWS Glue ETL job]
    E --> F[S3 processed Parquet prefix]
    F --> G[AWS Glue crawler]
    G --> H[Glue Data Catalog table]
    H --> I[Amazon Athena SQL queries]
    I --> J[S3 Athena query results CSV]
    T[GitHub repository] --> U[GitHub Actions validation]
    T --> V[HCP Terraform]
    V --> W[AWS infrastructure]
```

### AWS resources used

-   **Amazon S3:** Private data lake bucket for raw JSON, processed
    Parquet, the Glue script, and Athena query results.
-   **AWS Lambda:** Receives a test event and writes a JSON batch to the
    raw S3 prefix.
-   **Amazon DynamoDB:** Stores ingestion metadata keyed by `batch_id`.
-   **AWS Glue job:** Reads raw JSON, explodes the `records` array,
    validates required fields, and writes Parquet.
-   **AWS Glue Data Catalog and crawler:** Infers the processed dataset
    schema and creates a table.
-   **Amazon Athena:** Runs SQL against the catalog table and saves
    query results to S3.
-   **Amazon VPC:** Terraform provisions a VPC and public/private subnet
    resources as a foundation for future platform work.
-   **HCP Terraform:** Provides remote Terraform state and execution.
-   **GitHub Actions:** Runs Terraform formatting/validation checks.

## Technology stack

  Area                        Technology
  --------------------------- -----------------------------------
  Cloud                       AWS
  Infrastructure as code      Terraform
  Terraform workflow/state    HCP Terraform
  CI                          GitHub Actions
  Ingestion                   AWS Lambda, Python, Boto3
  Raw and processed storage   Amazon S3
  Ingestion metadata          Amazon DynamoDB
  ETL                         AWS Glue, Apache Spark, PySpark
  Schema discovery            AWS Glue Data Catalog and crawler
  SQL analytics               Amazon Athena
  Network foundation          Amazon VPC

## Repository layout

The repository is organized around reusable Terraform modules,
environment-specific configuration, application code, and automation.

``` text
aws-production-data-platform/
├── modules/
│   ├── iam/
│   ├── networking/
│   ├── s3-data-lake/
│   ├── lambda/
│   ├── dynamodb/
│   ├── glue/
│   ├── emr/                 # planned
│   └── redshift/            # planned
├── environments/
│   ├── dev/
│   ├── staging/              # planned
│   └── prod/                 # planned
├── applications/
│   ├── ingestion/
│   │   └── lambda_function.py
│   ├── glue-jobs/
│   │   └── transform.py
│   └── spark-jobs/           # planned
├── cloudformation/           # planned examples
├── tests/                    # expanding
├── scripts/
└── .github/
    └── workflows/
```

The exact files in the repository may evolve as the project progresses.

## Data flow

1.  A test event supplies a `records` array to the Lambda function.

2.  Lambda validates the event and writes a JSON envelope to a key such
    as:

    ``` text
    raw/year=YYYY/month=MM/day=DD/<uuid>.json
    ```

3.  The Lambda function records batch metadata in DynamoDB.

4.  The Glue job reads JSON files from `raw/`, explodes the `records`
    array into individual events, selects fields such as `event_id`,
    `event_type`, `amount`, and `currency`, and writes Parquet files to
    `processed/`.

5.  The Glue crawler scans the processed prefix and updates the Glue
    Data Catalog.

6.  Athena queries the catalog table and writes query-result files,
    including CSV output, to the configured `athena-results/` S3 prefix.

S3 "folders" are key prefixes, not separate directories that must be
created in advance. An object written with a key beginning with `raw/`
creates the visible prefix in the S3 console.

## Current implementation

### Terraform and IAM

-   Reusable modules are used for infrastructure components.
-   The S3 data lake bucket is configured with public access blocked,
    server-side encryption, versioning, and bucket-owner-enforced object
    ownership.
-   Lambda and Glue use separate execution roles.
-   Lambda has permissions for S3 ingestion and writing metadata to the
    configured DynamoDB table.
-   Glue has permissions for its service role and data-lake object
    access.
-   HCP Terraform is used for Terraform state and execution; a separate
    S3 Terraform backend is not intended.

### Lambda ingestion

The ingestion function uses Python 3.12 and writes a JSON batch to S3.
The function receives its bucket and metadata table through environment
variables.

Example test event:

``` json
{
  "records": [
    {
      "event_id": "evt-001",
      "event_type": "purchase",
      "amount": 250.75,
      "currency": "INR"
    },
    {
      "event_id": "evt-002",
      "event_type": "refund",
      "amount": 50.00,
      "currency": "INR"
    },
    {
      "event_id": "evt-003",
      "event_type": "purchase",
      "amount": 499.99,
      "currency": "INR"
    }
  ]
}
```

### Glue transformation

The Glue job is designed to:

-   Read JSON under the configured raw S3 prefix.
-   Explode the top-level `records` array.
-   Cast and select the expected event fields.
-   Filter records missing `event_id` or `event_type`.
-   Write Parquet to the processed S3 prefix.

**Important:** The current implementation is still being validated for
safe reruns and duplicate handling. Overwrite mode may be suitable for a
disposable development dataset, but it is not a complete idempotency
strategy for a production data lake with multiple batches. A future
version should track processed batch identifiers and define how retries,
late arrivals, and reprocessing are handled.

## Prerequisites

-   An AWS account with permission to create the resources in this
    project.
-   Terraform CLI installed.
-   An HCP Terraform organization and workspace configured for the
    project.
-   Git and a GitHub repository.
-   AWS credentials configured for the Terraform execution environment.
-   AWS Console or AWS CLI access for testing Lambda, S3, Glue,
    DynamoDB, and Athena.

Use a non-production AWS account and region while learning. Confirm the
region and account before applying changes.

## Deploying the development environment

> Review the actual configuration and workspace settings in your
> repository before running these commands. Terraform can create
> billable resources.

From the repository root, initialize and validate the development
Terraform configuration:

``` bash
terraform -chdir=environments/dev init
terraform -chdir=environments/dev fmt -check
terraform -chdir=environments/dev validate
```

If the project uses HCP Terraform remote execution, `init` should
connect to the configured workspace. Do not add a local or S3 backend
unless you intentionally redesign the state configuration.

Review the plan in HCP Terraform before applying it. Confirm the target
account, region, resource changes, and any destroy actions.

## Testing the pipeline

Run these checks in order:

1.  **Lambda:** Invoke the function with the sample event and confirm a
    successful execution.
2.  **S3 raw:** Confirm a new JSON object exists under `raw/` in the
    same bucket configured for the Glue job.
3.  **DynamoDB:** Confirm the corresponding ingestion metadata item
    exists.
4.  **Glue ETL:** Run the Glue job and confirm the run status is
    `SUCCEEDED`.
5.  **S3 processed:** Confirm Parquet objects exist under the exact
    `--PROCESSED_PATH` used by the Glue job.
6.  **Crawler:** Run the crawler and confirm it succeeds.
7.  **Data Catalog:** Confirm the crawler-created table's `Location`
    matches the processed S3 prefix.
8.  **Athena:** Run a simple `SELECT` and aggregation query.
9.  **Duplicate check:** Group by event fields and verify whether any
    event appears more than once.

The raw path, Glue job arguments, crawler table location, and Athena
database/table must all refer to the same environment and data lake.

## Example Athena queries

Replace the database and table placeholders with the actual names shown
in the Glue Data Catalog.

### Inspect records

``` sql
SELECT *
FROM "your_catalog_database"."your_table_name"
LIMIT 10;
```

### Count events by type

``` sql
SELECT
    event_type,
    COUNT(*) AS event_count
FROM "your_catalog_database"."your_table_name"
GROUP BY event_type
ORDER BY event_count DESC;
```

### Calculate totals

``` sql
SELECT
    currency,
    event_type,
    COUNT(*) AS record_count,
    SUM(amount) AS total_amount
FROM "your_catalog_database"."your_table_name"
GROUP BY currency, event_type
ORDER BY currency, event_type;
```

### Detect duplicate records

``` sql
SELECT
    event_id,
    event_type,
    amount,
    currency,
    COUNT(*) AS copies
FROM "your_catalog_database"."your_table_name"
GROUP BY event_id, event_type, amount, currency
HAVING COUNT(*) > 1
ORDER BY copies DESC;
```

For the sample event batch, if it has been ingested and processed
exactly once, the expected totals are:

-   `purchase`: 2 events, total amount `750.74 INR`
-   `refund`: 1 event, total amount `50.00 INR`
-   Total: 3 events, amount `800.74 INR`

These expected values apply only to that single sample batch. Additional
raw files will change the results unless the query filters to a specific
batch or dataset.

### Athena query result location

Athena query results are written to the configured S3 result prefix, for
example:

``` text
s3://YOUR-ACTUAL-BUCKET-NAME/athena-results/
```

Use the actual bucket configured in the Athena workgroup. The identity
running Athena needs the appropriate permissions to query the catalog
and read the data, as well as write query results to that S3 location.

## Configuration notes

-   The development bucket name observed during testing was:

    ``` text
    aws-prod-data-platform-dev-611346097660-us-east-1
    ```

    This is environment-specific. Do not assume it will be the same in
    another account or region.

-   The Glue job's raw and processed paths must match the actual bucket
    and prefixes used by the Lambda function and crawler.

-   The Terraform networking module provisions a VPC with public and
    private subnets. In the current design, Lambda is not attached to
    those subnets. Private subnet routing and NAT/VPC endpoint decisions
    should be reviewed before workloads are placed there.

-   GitHub Actions validation and HCP Terraform infrastructure execution
    are separate parts of the workflow.

## Security and cost considerations

-   Never commit AWS access keys, secret keys, state files, or sensitive
    Terraform variable files to Git.
-   Prefer short-lived credentials and OIDC federation for CI where
    supported.
-   Keep S3 Block Public Access enabled and use least-privilege IAM
    policies.
-   Check CloudWatch logs for sensitive data before logging payloads.
-   Glue jobs and crawlers, Athena scans, DynamoDB point-in-time
    recovery, and other AWS resources may incur charges.
-   Stop unnecessary jobs and remove temporary resources after testing.
-   Inspect Terraform plans carefully, especially before destroying or
    recreating resources.
-   S3 bucket versioning and `force_destroy = false` can prevent
    accidental data loss, but may also require deliberate cleanup during
    teardown.

## Known issues and next steps

-   **Duplicate records:** Athena previously returned two copies of each
    of the three sample events. The processed dataset and table location
    need to be checked after the infrastructure reset. Do not consider
    duplicate handling complete until the duplicate-check query returns
    no unexpected duplicates.
-   **Safe reruns:** Replace the development-only overwrite workaround
    with batch-aware idempotency before treating the pipeline as
    production-ready.
-   **Automated testing:** Add tests for valid and invalid Lambda
    events, S3 output, DynamoDB metadata, Glue transformation behavior,
    and end-to-end row counts.
-   **Reliability and observability:** Add structured logs, actionable
    metrics, alarms, retry behavior, and documented failure recovery.
-   **Security:** Review IAM scope, secret handling, network design, and
    data retention.
-   **Documentation:** Add an architecture diagram, deployment evidence,
    troubleshooting steps, and a teardown guide as the implementation
    stabilizes.

## Planned roadmap

  -----------------------------------------------------------------------
  Stage                   Focus                   Status
  ----------------------- ----------------------- -----------------------
  Days 1--3               Terraform foundation,   Completed in initial
                          IAM/networking/S3,      testing
                          Lambda ingestion,       
                          DynamoDB metadata       

  Day 4                   Glue ETL, crawler, Data In progress; duplicate
                          Catalog, Athena         issue being
                                                  investigated

  Day 5                   Automated end-to-end    Planned
                          tests and error         
                          handling                

  Day 6                   EMR/Spark demonstration Planned

  Day 7                   Redshift analytics      Planned
                          integration or a        
                          cost-conscious          
                          alternative             

  Day 8                   Security hardening and  Planned
                          least-privilege IAM     

  Day 9                   CI/CD improvements and  Planned
                          CloudFormation example  

  Day 10                  Reliability, retries,   Planned
                          metrics, and SRE        
                          practices               

  Day 11                  Full integration and    Planned
                          operational testing     

  -----------------------------------------------------------------------

## Cleanup

Before destroying resources:

1.  Review the HCP Terraform plan and confirm the workspace, account,
    and region.
2.  Preserve any data or logs you need for the portfolio.
3.  Check for S3 objects, Athena result files, and versioned objects.
4.  Destroy only resources you intend to remove.
5.  Verify the final state in AWS and HCP Terraform.

The data lake bucket is configured with `force_destroy = false`, so
Terraform may refuse to delete it while objects remain. Versioned
buckets may also retain older object versions. Clean up intentionally
and verify what will be deleted before confirming any destructive
action.

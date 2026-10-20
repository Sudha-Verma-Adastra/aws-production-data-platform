# Project Troubleshooting Log

**Project:** AWS Production Data Engineering Platform\
**Repository:**
https://github.com/Sudha-Verma-Adastra/aws-production-data-platform\
**Last updated:** 20 October 2026

This log records errors, suspected causes, code/configuration changes,
validation, and outcomes reported during project work. Do not add API
tokens, credentials, or other secrets.

## Current status summary

-   HCP Terraform plan trigger: working; latest plan reported
    successful.
-   Latest plan: **36 to add, 0 to change, 0 to destroy** (reported by
    user); resource list review and apply are pending.
-   Data pipeline: previously tested end to end before clean
    infrastructure rebuild; post-rebuild verification pending.
-   Ruff: passed locally after fixes.
-   TFLint: passed locally after module constraints/unused-variable
    cleanup.
-   Python tests: six tests reported passing after test expectation was
    updated.
-   Checkov: removed/deferred from active CI by decision; findings are
    not resolved.

## 1. Glue overwrite failed to delete S3 marker

**Error:** Glue overwrite failed because the execution role lacked
permission to delete `processed_$folder$`.

**Suspected cause:** Missing scoped `s3:DeleteObject` permission for the
relevant marker object.

**Change:** Added a dedicated `s3:DeleteObject` policy scoped to the
required object/key for the Glue role.

**Validation:** User confirmed success after the change.

**Outcome:** Fixed and validated at that point. Keep permissions
narrowly scoped; avoid broad `s3:*`.

## 2. Duplicate records in Athena

**Symptom:** Earlier Athena validation returned two copies of each of
three sample events.

**Suspected cause:** Repeated output/processed data or catalog-location
issues during reruns; overwrite alone was not a complete idempotency
strategy.

**Change:** Updated Glue transformation to deduplicate with a window
partitioned by `event_id`, ordered by `ingested_at` descending and then
`batch_id` descending, retaining the latest row per event ID.

**Validation before infrastructure reset:** Two JSON batches of three
records each resulted in six Athena rows and six distinct event IDs.
Purchases: four records totaling INR 1,301.23. Refunds: two records
totaling INR 125.00. DynamoDB showed two successful batches with three
records each.

**Outcome:** The change was tested in the earlier environment. Repeat
the checks after the current rebuild.

**Follow-up:** Define batch-aware idempotency, retry behavior,
late-arriving events, and reprocessing policy before claiming production
readiness.

## 3. Ruff lint errors

**Initial issues:** - `I001`: unsorted imports in
`.github/scripts/trigger_hcp_terraform_plan.py`. - `TRY004`: `TypeError`
preferred for invalid event type in
`applications/ingestion/lambda_function.py`. - `UP017`: use
`datetime.UTC`. - `F401`: unused `importlib` in
`tests/test_lambda_ingestion.py`.

**Changes:** Ran `python -m ruff check . --fix`, changed invalid event
type from `ValueError` to `TypeError`, updated
`test_non_object_event_is_rejected` to expect `TypeError`, and removed
the unused import.

**Validation:** `python -m ruff check .` passed. The first test run had
one stale expectation; after updating it, the user reported success and
all six tests passed.

**Outcome:** Fixed and validated locally.

## 4. TFLint warnings

**Initial issue:** `tflint --recursive` exited with code 2 and reported
16 warnings, including missing module-level Terraform/AWS provider
constraints and unused EMR variables.

**Changes:** Added module-local `required_version = ">= 1.5.0, < 2.0.0"`
and AWS provider constraint `~> 5.0` to `modules/dynamodb`,
`modules/emr`, `modules/glue`, `modules/iam`, `modules/lambda`,
`modules/networking`, and `modules/s3-data-lake`. Removed unused
`aws_region` and `data_lake_bucket_name` variables/arguments from the
EMR module while retaining the data lake bucket ARN.

**Validation:** User reported `tflint --recursive` exit code 0.

**Outcome:** Fixed and validated locally.

## 5. Checkov findings deferred

**Initial scan:** 145 passed, 19 failed.

**Later report:** 148 passed, 17 failed. Glue job/crawler and Athena
workgroup checks were passing. Reported remaining checks included: -
`CKV_AWS_119`: DynamoDB customer-managed KMS encryption. - `CKV_AWS_99`:
Glue security configuration encryption. - Lambda: `CKV_AWS_173`,
`CKV_AWS_115`, `CKV_AWS_50`, `CKV_AWS_117`, `CKV_AWS_272`,
`CKV_AWS_116`. - Networking: `CKV_AWS_394`, `CKV2_AWS_12`,
`CKV2_AWS_11`. - S3: `CKV2_AWS_62`, `CKV_AWS_18`, `CKV_AWS_144`,
`CKV2_AWS_61`, `CKV_AWS_145`. - EMR: `CKV2_AWS_55`.

**Decision:** User explicitly asked to skip Checkov dependency for now.
The workflow was changed in a commit titled `remove checkov dep`.

**Outcome:** Remediation is deferred. Do not call these findings fixed.
Removing a scanner from CI does not make its findings pass. Keep the
report for a future security-hardening pass.

## 6. GitHub Actions could not find HCP plan script

**Error:**

``` text
python: can't open file '/home/runner/work/aws-production-data-platform/aws-production-data-platform/.github/scripts/trigger_hcp_terraform_plan.py': [Errno 2] No such file or directory
```

**Investigation:** Locally, `ls -la .github/scripts/` showed the script.
`git ls-files .github/scripts/trigger_hcp_terraform_plan.py` printed the
expected path. Branch status showed `HEAD -> main, origin/main` at
commit `68d13b7` (`remove checkov dep`) with no working-tree changes.

**Change proposed:** Add an explicit `actions/checkout@v4` step and
diagnostic commands to print working directory, commit SHA, list
`.github/scripts/`, and test the script path before invoking it.

**Validation:** A later API error was reported, so the workflow
progressed beyond the script-not-found symptom. The original
missing-file root cause was not conclusively established.

## 7. HCP Terraform API returned HTTP 404

**Error:**

``` text
ERROR: HCP Terraform API returned HTTP 404: {"errors":[{"status":"404","title":"not found"}]}
```

**Possible causes considered:** Incorrect workspace ID, organization
mismatch, or token authorization/type. The exact failing endpoint was
not captured.

**Change:** No specific code fix is confirmed in the project record.

**Outcome:** User later reported "plan success," so a later run
succeeded. The root cause of the earlier 404 remains unconfirmed.

**Security note:** Never print/share the HCP token. For future 404s, log
HTTP method and endpoint path only, without headers or secrets, and
verify workspace ID, organization, and token permissions.

## 8. Latest HCP Terraform plan

**Reported result:** Plan succeeded; user reported **36 to add only**,
interpreted in context as 36 add, zero change, zero destroy.

**Still pending:** The complete resource list has not been reviewed in
the conversation and apply has not been confirmed.

**Next actions:** 1. Review every planned resource. 2. Verify workspace,
AWS account, and region. 3. Confirm optional EMR/Redshift resources are
not unexpectedly enabled. 4. Review costs, public exposure, IAM changes,
and resource names. 5. Keep auto-apply disabled. 6. Apply only after
explicit review and approval. 7. Repeat end-to-end data tests after
apply.

## Standard validation commands

Run from the repository root:

``` bash
terraform fmt -recursive -check
terraform -chdir=environments/dev validate
tflint --recursive
python -m ruff check .
python -m pytest -q
git diff --check
```

Run Checkov only when deliberately reintroducing the security scan.
Record both failed and skipped findings; a skip is an exception, not a
fix.

## Post-deployment acceptance checklist

-   [ ] HCP plan reviewed and approved manually.
-   [ ] Apply succeeds.
-   [ ] AWS resources match the approved plan.
-   [ ] Lambda invocation succeeds.
-   [ ] Raw JSON appears in S3.
-   [ ] DynamoDB metadata is correct.
-   [ ] Glue succeeds and writes Parquet.
-   [ ] Crawler and catalog table location are correct.
-   [ ] Athena row counts and aggregates match expected results.
-   [ ] Duplicate query shows no unexpected duplicates.
-   [ ] Retry/rerun behavior is tested.
-   [ ] Residual resources and costs are checked.

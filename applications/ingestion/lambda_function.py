import json
import os
import uuid
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
BUCKET_NAME = os.environ["DATA_LAKE_BUCKET"]


def lambda_handler(event, context):
    """Validate a batch of JSON records and persist them to S3."""

    if not isinstance(event, dict):
        raise ValueError("Event must be a JSON object")

    records = event.get("records", [event])

    if not isinstance(records, list) or not records:
        raise ValueError("'records' must be a non-empty list")

    if not all(isinstance(record, dict) for record in records):
        raise ValueError("Every record must be a JSON object")

    now = datetime.now(timezone.utc)
    object_key = (
        f"raw/year={now:%Y}/month={now:%m}/day={now:%d}/"
        f"{uuid.uuid4()}.json"
    )

    payload = {
        "ingested_at": now.isoformat(),
        "record_count": len(records),
        "records": records,
    }

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=object_key,
        Body=json.dumps(payload).encode("utf-8"),
        ContentType="application/json",
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Ingestion successful",
            "bucket": BUCKET_NAME,
            "key": object_key,
            "record_count": len(records),
        }),
    }

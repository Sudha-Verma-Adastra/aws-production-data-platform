import json
import os
import uuid
from datetime import UTC, datetime

import boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

BUCKET_NAME = os.environ["DATA_LAKE_BUCKET"]
METADATA_TABLE = os.environ["METADATA_TABLE"]
table = dynamodb.Table(METADATA_TABLE)


def lambda_handler(event, context):
    if not isinstance(event, dict):
        raise TypeError("Event must be a JSON object")

    records = event.get("records", [event])

    if not isinstance(records, list) or not records:
        raise ValueError("'records' must be a non-empty list")

    if not all(isinstance(record, dict) for record in records):
        raise ValueError("Every record must be a JSON object")

    now = datetime.now(UTC)
    batch_id = str(uuid.uuid4())

    object_key = (
        f"raw/year={now:%Y}/month={now:%m}/day={now:%d}/"
        f"{batch_id}.json"
    )

    payload = {
        "batch_id": batch_id,
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

    table.put_item(
        Item={
            "batch_id": batch_id,
            "status": "SUCCEEDED",
            "s3_bucket": BUCKET_NAME,
            "s3_key": object_key,
            "record_count": len(records),
            "ingested_at": now.isoformat(),
        }
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Ingestion successful",
            "batch_id": batch_id,
            "bucket": BUCKET_NAME,
            "key": object_key,
            "record_count": len(records),
        }),
    }

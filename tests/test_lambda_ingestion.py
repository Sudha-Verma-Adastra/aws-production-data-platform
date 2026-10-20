
import importlib
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# Configure the environment before importing the Lambda module.
os.environ["DATA_LAKE_BUCKET"] = "test-data-lake"
os.environ["METADATA_TABLE"] = "test-metadata"

REPO_ROOT = Path(__file__).resolve().parents[1]
INGESTION_DIR = REPO_ROOT / "applications" / "ingestion"
sys.path.insert(0, str(INGESTION_DIR))

with patch("boto3.client"), patch("boto3.resource"):
    import lambda_function


class TestLambdaIngestion(unittest.TestCase):
    def setUp(self):
        self.s3 = MagicMock()
        self.table = MagicMock()

        lambda_function.s3 = self.s3
        lambda_function.table = self.table
        lambda_function.BUCKET_NAME = "test-data-lake"
        lambda_function.METADATA_TABLE = "test-metadata"

        self.records = [
            {
                "event_id": "evt-001",
                "event_type": "purchase",
                "amount": 250.75,
                "currency": "INR",
            },
            {
                "event_id": "evt-002",
                "event_type": "refund",
                "amount": 50.00,
                "currency": "INR",
            },
        ]

    def test_valid_batch_writes_s3_and_dynamodb(self):
        response = lambda_function.lambda_handler(
            {"records": self.records}, None
        )

        self.assertEqual(response["statusCode"], 200)

        body = json.loads(response["body"])
        self.assertEqual(body["record_count"], 2)
        self.assertEqual(body["bucket"], "test-data-lake")
        self.assertTrue(body["key"].startswith("raw/year="))

        self.s3.put_object.assert_called_once()
        s3_call = self.s3.put_object.call_args.kwargs

        self.assertEqual(s3_call["Bucket"], "test-data-lake")
        self.assertEqual(s3_call["Key"], body["key"])
        self.assertEqual(s3_call["ContentType"], "application/json")

        payload = json.loads(s3_call["Body"].decode("utf-8"))
        self.assertEqual(payload["records"], self.records)
        self.assertEqual(payload["record_count"], 2)
        self.assertEqual(payload["batch_id"], body["batch_id"])

        self.table.put_item.assert_called_once()
        item = self.table.put_item.call_args.kwargs["Item"]

        self.assertEqual(item["batch_id"], body["batch_id"])
        self.assertEqual(item["status"], "SUCCEEDED")
        self.assertEqual(item["record_count"], 2)
        self.assertEqual(item["s3_bucket"], "test-data-lake")
        self.assertEqual(item["s3_key"], body["key"])

    def test_single_record_event_is_supported(self):
        response = lambda_function.lambda_handler(
            self.records[0], None
        )

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(
            json.loads(response["body"])["record_count"], 1
        )

    def test_non_object_event_is_rejected(self):
        with self.assertRaisesRegex(
            ValueError, "Event must be a JSON object"
        ):
            lambda_function.lambda_handler(["invalid"], None)

        self.s3.put_object.assert_not_called()
        self.table.put_item.assert_not_called()

    def test_empty_records_are_rejected(self):
        with self.assertRaisesRegex(
            ValueError, "'records' must be a non-empty list"
        ):
            lambda_function.lambda_handler({"records": []}, None)

        self.s3.put_object.assert_not_called()
        self.table.put_item.assert_not_called()

    def test_records_must_be_a_list(self):
        with self.assertRaisesRegex(
            ValueError, "'records' must be a non-empty list"
        ):
            lambda_function.lambda_handler(
                {"records": "not-a-list"}, None
            )

    def test_each_record_must_be_an_object(self):
        with self.assertRaisesRegex(
            ValueError, "Every record must be a JSON object"
        ):
            lambda_function.lambda_handler(
                {"records": [self.records[0], "invalid"]}, None
            )

        self.s3.put_object.assert_not_called()
        self.table.put_item.assert_not_called()


if __name__ == "__main__":
    unittest.main()

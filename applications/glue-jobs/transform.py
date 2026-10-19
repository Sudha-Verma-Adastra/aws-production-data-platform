import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "RAW_PATH", "PROCESSED_PATH"],
)

sc = SparkContext.getOrCreate()
glue_context = GlueContext(sc)
spark = glue_context.spark_session

job = Job(glue_context)
job.init(args["JOB_NAME"], args)

raw_path = args["RAW_PATH"]
processed_path = args["PROCESSED_PATH"]

# Each raw object contains batch_id, ingested_at,
# record_count, and a records array.
raw_df = (
    spark.read
    .option("recursiveFileLookup", "true")
    .json(raw_path)
)

if "records" not in raw_df.columns:
    raise ValueError("Raw input does not contain a records field")

# Convert the nested records array into one row per event.
events_df = raw_df.select(
    F.col("batch_id").alias("batch_id"),
    F.col("ingested_at").alias("ingested_at"),
    F.explode("records").alias("event"),
)

# Select a stable analytics schema.
processed_df = events_df.select(
    "batch_id",
    "ingested_at",
    F.col("event.event_id").cast("string").alias("event_id"),
    F.col("event.event_type").cast("string").alias("event_type"),
    F.col("event.amount").cast("double").alias("amount"),
    F.col("event.currency").cast("string").alias("currency"),
).filter(
    F.col("event_id").isNotNull()
    & F.col("event_type").isNotNull()
)

# Fail rather than silently producing an empty dataset.
if processed_df.limit(1).count() == 0:
    raise ValueError("No valid event records found in raw input")

(
    processed_df.write
    .mode("overwrite")
    .format("parquet")
    .save(processed_path)
)

job.commit()

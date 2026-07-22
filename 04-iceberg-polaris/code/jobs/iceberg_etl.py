"""
iceberg_etl.py — PySpark ETL job for Apache Iceberg with Polaris Catalog

Reads sales.csv, transforms data, and writes Iceberg tables registered in
the Polaris REST catalog. Then demonstrates Iceberg features: append,
time travel, and schema evolution.

Usage:
    spark-submit --conf spark.sql.catalog.polaris=... iceberg_etl.py

All catalog/S3 configuration is passed via spark-submit --conf flags.
"""

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    IntegerType,
    StringType,
    DoubleType,
    DateType,
)


def create_spark_session():
    """Create SparkSession — catalog configs come from spark-submit."""
    return (
        SparkSession.builder
        .appName("Iceberg ETL with Polaris")
        .getOrCreate()
    )


def run_basic_etl(spark):
    """Phase 1: Read CSV, transform, write Iceberg tables."""
    print("=" * 60)
    print("PHASE 1: Basic ETL — CSV to Iceberg Tables")
    print("=" * 60)

    # Define schema explicitly for reliability
    schema = StructType([
        StructField("id", IntegerType(), False),
        StructField("product", StringType(), False),
        StructField("category", StringType(), False),
        StructField("amount", DoubleType(), False),
        StructField("quantity", IntegerType(), False),
        StructField("sale_date", DateType(), False),
    ])

    # Step 1: Read CSV
    print("\nStep 1: Reading sales.csv...")
    df = (
        spark.read
        .option("header", "true")
        .schema(schema)
        .csv("/opt/spark-data/sales.csv")
    )
    print(f"  Loaded {df.count()} rows from sales.csv")
    df.show(truncate=False)

    # Step 2: Add computed column
    print("Step 2: Adding total_amount column (amount * quantity)...")
    df = df.withColumn("total_amount", F.col("amount") * F.col("quantity"))
    df.show(truncate=False)

    # Step 3: Create namespace
    print("Step 3: Creating namespace polaris.sales...")
    spark.sql("CREATE NAMESPACE IF NOT EXISTS polaris.sales")
    print("  Namespace 'polaris.sales' ready.")

    # Step 4: Write transactions table (partitioned by sale_date)
    print("Step 4: Writing polaris.sales.transactions (partitioned by sale_date)...")
    (
        df.writeTo("polaris.sales.transactions")
        .partitionedBy("sale_date")
        .createOrReplace()
    )
    tx_count = spark.table("polaris.sales.transactions").count()
    print(f"  Written {tx_count} rows to polaris.sales.transactions")

    # Step 5: Create sales_summary aggregation
    print("Step 5: Writing polaris.sales.sales_summary (aggregation by category)...")
    summary_df = (
        df.groupBy("category")
        .agg(
            F.sum("total_amount").alias("total_sales"),
            F.sum("quantity").alias("total_quantity"),
            F.count("*").alias("transaction_count"),
        )
    )
    summary_df.writeTo("polaris.sales.sales_summary").createOrReplace()
    summary_count = spark.table("polaris.sales.sales_summary").count()
    print(f"  Written {summary_count} rows to polaris.sales.sales_summary")
    summary_df.show(truncate=False)

    print("\n--- Phase 1 Complete: Basic ETL finished ---\n")
    return df


def run_iceberg_features(spark, original_df):
    """Phase 2: Demonstrate Iceberg features — append, time travel, schema evolution."""
    print("=" * 60)
    print("PHASE 2: Iceberg Features Demo")
    print("=" * 60)

    # --- Feature 1: Append new rows ---
    print("\nFeature 1: Appending 3 new rows to transactions...")
    new_rows = spark.createDataFrame(
        [
            (11, "Tablet", "Electronics", 599.99, 2, "2024-01-20", 1199.98),
            (12, "Standing Desk", "Furniture", 499.99, 1, "2024-01-20", 499.99),
            (13, "USB Hub", "Electronics", 39.99, 3, "2024-01-20", 119.97),
        ],
        schema=["id", "product", "category", "amount", "quantity", "sale_date", "total_amount"],
    )
    # Cast sale_date from string to date
    new_rows = new_rows.withColumn("sale_date", F.col("sale_date").cast(DateType()))

    new_rows.writeTo("polaris.sales.transactions").append()

    current_count = spark.table("polaris.sales.transactions").count()
    print(f"  After append: {current_count} total rows (expected 13)")

    # --- Feature 2: Time Travel ---
    print("\nFeature 2: Time Travel — querying snapshot history...")
    snapshots = spark.sql(
        "SELECT snapshot_id, committed_at, operation "
        "FROM polaris.sales.transactions.snapshots "
        "ORDER BY committed_at"
    )
    snapshots.show(truncate=False)

    # Get the first snapshot ID for time travel
    snapshot_rows = snapshots.collect()
    if len(snapshot_rows) >= 1:
        first_snapshot_id = snapshot_rows[0]["snapshot_id"]
        print(f"  First snapshot ID: {first_snapshot_id}")

        old_df = spark.read.option("snapshot-id", str(first_snapshot_id)).table(
            "polaris.sales.transactions"
        )
        old_count = old_df.count()
        print(f"  Snapshot #1 row count: {old_count} (expected 10)")
        print(f"  Current row count:     {current_count} (expected 13)")
        print(f"  Time travel verified: snapshot #1 has {old_count} rows, current has {current_count} rows")
    else:
        print("  WARNING: No snapshots found — skipping time travel demo.")

    # --- Feature 3: Schema Evolution ---
    print("\nFeature 3: Schema Evolution — adding 'region' column...")
    spark.sql(
        "ALTER TABLE polaris.sales.transactions "
        "ADD COLUMNS (region STRING COMMENT 'Sales region')"
    )
    print("  Column 'region' added successfully.")

    print("\n  Updated table schema:")
    spark.sql("DESCRIBE polaris.sales.transactions").show(truncate=False)

    # Verify existing data still readable with new schema (region = null)
    sample = spark.sql(
        "SELECT id, product, region FROM polaris.sales.transactions LIMIT 3"
    )
    print("  Sample rows (region should be null for existing data):")
    sample.show(truncate=False)

    print("\n--- Phase 2 Complete: Iceberg Features demonstrated ---\n")


def print_summary(spark):
    """Print final verification summary."""
    print("=" * 60)
    print("VERIFICATION SUMMARY")
    print("=" * 60)

    tx_count = spark.table("polaris.sales.transactions").count()
    summary_count = spark.table("polaris.sales.sales_summary").count()

    snapshots = spark.sql(
        "SELECT snapshot_id FROM polaris.sales.transactions.snapshots"
    ).collect()

    columns = [
        row["col_name"]
        for row in spark.sql("DESCRIBE polaris.sales.transactions").collect()
    ]

    print(f"  Transactions table:  {tx_count} rows (expected 13)")
    print(f"  Sales summary table: {summary_count} rows (expected 2)")
    print(f"  Snapshots count:     {len(snapshots)} (expected 3: create, append, schema evolution)")
    print(f"  Table columns:       {columns}")
    print(f"  Has 'region' column: {'region' in columns}")
    print()

    if tx_count == 13 and summary_count == 2 and "region" in columns:
        print("  ALL CHECKS PASSED")
    else:
        print("  SOME CHECKS FAILED — review output above")

    print("=" * 60)


if __name__ == "__main__":
    spark = create_spark_session()

    try:
        # Phase 1: Basic ETL
        original_df = run_basic_etl(spark)

        # Phase 2: Iceberg features
        run_iceberg_features(spark, original_df)

        # Final summary
        print_summary(spark)
    finally:
        spark.stop()

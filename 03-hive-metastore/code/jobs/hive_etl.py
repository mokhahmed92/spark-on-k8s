"""PySpark Hive ETL Application.

Demonstrates using Hive Metastore for table-based data management instead of
hard-coded file paths. Reads a CSV file, creates managed Hive tables, runs SQL
aggregations, and writes results — all using table names.

Usage:
    spark-submit hive_etl.py <input_csv_path>

The output goes to Hive managed tables (the metastore decides where data lives).
No output path argument needed — this is the key difference from file-based jobs.
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType, DateType
)


def main():
    if len(sys.argv) != 2:
        print("Usage: hive_etl.py <input_csv_path>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]

    spark = SparkSession.builder \
        .appName("HiveETL") \
        .enableHiveSupport() \
        .getOrCreate()

    # Define explicit schema to avoid type inference issues
    sales_schema = StructType([
        StructField("date", DateType(), True),
        StructField("product", StringType(), True),
        StructField("category", StringType(), True),
        StructField("quantity", IntegerType(), True),
        StructField("price", DoubleType(), True),
    ])

    # ------------------------------------------------------------------
    # Step 1: Read CSV and create managed Hive table
    # ------------------------------------------------------------------
    print(f"\n=== Step 1: Reading CSV from {input_path} ===")
    df = spark.read.csv(input_path, header=True, schema=sales_schema)
    print(f"Read {df.count()} rows from CSV")
    df.show(5)

    # Drop tables if they exist (for idempotent reruns)
    spark.sql("DROP TABLE IF EXISTS sales_raw")
    spark.sql("DROP TABLE IF EXISTS sales_summary")

    # Save as a managed Hive table (Parquet format at warehouse dir)
    df.write.saveAsTable("sales_raw")
    print("Created managed table: sales_raw")

    # ------------------------------------------------------------------
    # Step 2: Verify the table exists in the metastore
    # ------------------------------------------------------------------
    print("\n=== Step 2: Listing tables in default database ===")
    tables = spark.sql("SHOW TABLES IN default")
    tables.show()
    print(f"Tables in default database: {[row.tableName for row in tables.collect()]}")

    # ------------------------------------------------------------------
    # Step 3: Run SQL queries on the managed table
    # ------------------------------------------------------------------
    print("\n=== Step 3: Sales by category ===")
    category_sales = spark.sql("""
        SELECT
            category,
            SUM(quantity) AS total_quantity,
            ROUND(SUM(quantity * price), 2) AS total_revenue
        FROM sales_raw
        GROUP BY category
        ORDER BY total_revenue DESC
    """)
    category_sales.show()

    print("=== Step 3b: Top products by revenue ===")
    top_products = spark.sql("""
        SELECT
            product,
            category,
            SUM(quantity) AS total_quantity,
            ROUND(SUM(quantity * price), 2) AS total_revenue
        FROM sales_raw
        GROUP BY product, category
        ORDER BY total_revenue DESC
    """)
    top_products.show()

    print("=== Step 3c: Daily sales trend ===")
    daily_trend = spark.sql("""
        SELECT
            date,
            COUNT(DISTINCT product) AS products_sold,
            SUM(quantity) AS total_quantity,
            ROUND(SUM(quantity * price), 2) AS daily_revenue
        FROM sales_raw
        GROUP BY date
        ORDER BY date
    """)
    daily_trend.show()

    # ------------------------------------------------------------------
    # Step 4: Write aggregated results to a managed table
    # ------------------------------------------------------------------
    print("\n=== Step 4: Creating summary table ===")
    category_sales.write.saveAsTable("sales_summary")
    print("Created managed table: sales_summary")

    # ------------------------------------------------------------------
    # Step 5: Read back from the managed table to confirm persistence
    # ------------------------------------------------------------------
    print("\n=== Step 5: Reading back from sales_summary ===")
    result = spark.sql("SELECT * FROM sales_summary ORDER BY total_revenue DESC")
    result.show()
    print(f"sales_summary contains {result.count()} rows")

    # Final summary
    print("\n=== ETL Complete ===")
    print("Tables in default database:")
    spark.sql("SHOW TABLES IN default").show()
    print("Warehouse directory contents are managed by the Hive Metastore.")
    print("No output paths needed — the metastore tracks where data lives.")

    spark.stop()


if __name__ == "__main__":
    main()

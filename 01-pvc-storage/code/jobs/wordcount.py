"""PySpark Word Count Application.

Reads a text file, counts word occurrences, and writes the results.
Accepts input and output paths as command-line arguments.

Usage:
    spark-submit wordcount.py <input_path> <output_path>

Paths can be:
    - Local filesystem: /data/input/sample-input.txt
    - S3A (MinIO):      s3a://spark-data/input/sample-input.txt
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, split, lower, trim, col, length


def main():
    if len(sys.argv) != 3:
        print("Usage: wordcount.py <input_path> <output_path>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    spark = SparkSession.builder \
        .appName("WordCount") \
        .getOrCreate()

    # Read input text file
    lines = spark.read.text(input_path)

    # Split lines into words, normalize to lowercase, filter empty strings
    words = lines.select(
        explode(split(lower(trim(col("value"))), r"\s+")).alias("word")
    ).filter(length(col("word")) > 0)

    # Count occurrences of each word
    word_counts = words.groupBy("word").count().orderBy(col("count").desc())

    # Write results
    word_counts.write.mode("overwrite").csv(output_path)

    print(f"Word count complete. Results written to: {output_path}")

    spark.stop()


if __name__ == "__main__":
    main()

# Stage 1: Download Iceberg JARs (iceberg-spark-runtime + iceberg-aws-bundle)
FROM eclipse-temurin:17-jre AS downloader

ARG ICEBERG_VERSION=1.10.1

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && mkdir -p /tmp/jars \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fSL -o /tmp/jars/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar"

RUN curl -fSL -o /tmp/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar"

# Stage 2: Build custom Spark image with Iceberg support
FROM apache/spark:3.5.4-python3

USER root

# Copy Iceberg JARs into Spark's classpath
COPY --from=downloader /tmp/jars/*.jar ${SPARK_HOME}/jars/

# Copy sample application and data
COPY jobs/ /opt/spark-apps/
COPY data/ /opt/spark-data/

# Switch back to the Spark user (UID 185)
USER 185

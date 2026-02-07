# Stage 1: Download S3A JARs (hadoop-aws + AWS SDK bundle)
FROM eclipse-temurin:17-jre AS downloader

ARG HADOOP_AWS_VERSION=3.3.6
ARG AWS_SDK_VERSION=1.12.367

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && mkdir -p /tmp/jars \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fSL -o /tmp/jars/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar"

RUN curl -fSL -o /tmp/jars/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar \
    "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar"

# Stage 2: Build custom Spark image with S3A support
FROM apache/spark:3.5.4-python3

USER root

# Copy S3A JARs into Spark's classpath
COPY --from=downloader /tmp/jars/*.jar ${SPARK_HOME}/jars/

# Copy sample application and data
COPY jobs/ /opt/spark-apps/
COPY data/ /opt/spark-data/

# Switch back to the Spark user (UID 185)
USER 185

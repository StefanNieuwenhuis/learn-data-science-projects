FROM eclipse-temurin:17-jre-jammy

ENV SPARK_VERSION=4.1.1
ENV ICEBERG_JAVA_VERSION=1.10.1
ENV HADOOP_AWS_VERSION=3.4.2
ENV AWS_SDK_V2_VERSION=2.35.4

ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}"

# procps needed by spark-daemon.sh
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Spark
RUN mkdir -p ${SPARK_HOME} && \
    curl -fsSL \
        "https://www.apache.org/dyn/closer.lua/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz?action=download" \
        -o /tmp/spark.tgz && \
    tar -xzf /tmp/spark.tgz --directory ${SPARK_HOME} --strip-components 1 && \
    rm /tmp/spark.tgz

# Iceberg Spark runtime
RUN curl -fsSL \
    "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.0_2.13/${ICEBERG_JAVA_VERSION}/iceberg-spark-runtime-4.0_2.13-${ICEBERG_JAVA_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/iceberg-spark-runtime-4.0_2.13-${ICEBERG_JAVA_VERSION}.jar"

# Iceberg AWS bundle (S3FileIO)
RUN curl -fsSL \
    "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_JAVA_VERSION}/iceberg-aws-bundle-${ICEBERG_JAVA_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/iceberg-aws-bundle-${ICEBERG_JAVA_VERSION}.jar"

# hadoop-aws
RUN curl -fsSL \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/hadoop-aws-${HADOOP_AWS_VERSION}.jar"

# AWS SDK v2 bundle
RUN curl -fsSL \
    "https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/${AWS_SDK_V2_VERSION}/bundle-${AWS_SDK_V2_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/aws-sdk-bundle-${AWS_SDK_V2_VERSION}.jar"
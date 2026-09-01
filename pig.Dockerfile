# Builds a Pig-capable container on top of the same Hadoop base your namenode/datanode use.
# NOTE: if your course gave you a specific "pig" image name in a past lab, use that instead —
# just swap the `pig:` service in docker-compose.yml back to `image: <that-image>`.
# This Dockerfile is a reliable fallback since there is no official bde2020/pig image.

FROM bde2020/hadoop-base:2.0.0-hadoop2.7.4-java8

ENV PIG_VERSION=0.17.0
ENV PIG_HOME=/opt/pig
ENV PATH=$PATH:$PIG_HOME/bin

RUN wget -q https://archive.apache.org/dist/pig/pig-${PIG_VERSION}/pig-${PIG_VERSION}.tar.gz \
    && tar -xzf pig-${PIG_VERSION}.tar.gz -C /opt \
    && mv /opt/pig-${PIG_VERSION} ${PIG_HOME} \
    && rm pig-${PIG_VERSION}.tar.gz

WORKDIR /data
ENTRYPOINT ["tail", "-f", "/dev/null"]

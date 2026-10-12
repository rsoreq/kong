FROM kong/kong:3.9.4-ubuntu@sha256:da2afeecfec0561dd2e06612b09c6283d79245a0387acdc3715271dbf5691a05

USER root

RUN apt-get update

RUN apt-get install -y \
        build-essential \
        unzip \
        git \
        m4 \
        libyaml-dev

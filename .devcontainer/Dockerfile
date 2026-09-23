FROM kong/kong:3.9.3-ubuntu@sha256:9a2ae6699a2ce0d60592eb176555d3594a22782c20cc6557a61ff3a7e8b559a3

USER root

RUN apt-get update

RUN apt-get install -y \
        build-essential \
        unzip \
        git \
        m4 \
        libyaml-dev

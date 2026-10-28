FROM kong/kong:3.0.0-ubuntu@sha256:e076b149f79c17a539020167510bdfab68892122bef13cbd25b57ac42ee5ad21

USER root

RUN apt-get update

RUN apt-get install -y \
        build-essential \
        unzip \
        git \
        m4 \
        libyaml-dev

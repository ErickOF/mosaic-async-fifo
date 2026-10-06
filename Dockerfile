# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04@sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        g++ \
        git \
        libpython3.12t64 \
        make \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mosaic-flow /VERSION /opt/mosaic-flow/VERSION
COPY --from=mosaic-flow /ci /opt/mosaic-flow/ci
COPY --from=mosaic-flow /config /opt/mosaic-flow/config
COPY --from=mosaic-flow /flows /opt/mosaic-flow/flows
COPY --from=mosaic-flow /mk /opt/mosaic-flow/mk

RUN --mount=type=cache,id=oss-cad-suite,target=/opt/mosaic-tools/downloads \
    MOSAIC_TOOLS_ROOT=/opt/mosaic-tools /opt/mosaic-flow/ci/setup_open_source_tools.sh

ENV FLOW_ROOT=/opt/mosaic-flow \
    MOSAIC_TOOLS_ROOT=/opt/mosaic-tools \
    PYTHONPYCACHEPREFIX=/tmp/mosaic-pycache

ARG MOSAIC_FLOW_REVISION=unknown
LABEL org.opencontainers.image.description="Open-source RTL verification environment for MOSAIC modules" \
      org.opencontainers.image.source="https://github.com/ECASLab/mosaic-module-template" \
      org.opencontainers.image.title="MOSAIC module CI" \
      org.opencontainers.image.version="${MOSAIC_FLOW_REVISION}"

WORKDIR /workspace

ENTRYPOINT ["make"]
CMD ["open-source"]

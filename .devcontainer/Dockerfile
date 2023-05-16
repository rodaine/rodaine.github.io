ARG VARIANT="focal"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

ARG TARGETOS
ARG TARGETARCH
ARG HUGO="0.108.0"

RUN git config --global --add safe.directory /workspaces/rodaine.github.io
RUN cd /usr/local/bin \
    && curl --fail --silent --show-error -L https://github.com/gohugoio/hugo/releases/download/v${HUGO}/hugo_extended_${HUGO}_${TARGETOS}-${TARGETARCH}.tar.gz \
    |  tar zxv hugo

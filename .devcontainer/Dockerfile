ARG VARIANT="focal"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

ARG HUGO="0.108.0"
RUN cd /usr/local/bin \
    && curl -L https://github.com/gohugoio/hugo/releases/download/v${HUGO}/hugo_extended_${HUGO}_Linux-64bit.tar.gz \
    |  tar zxv hugo

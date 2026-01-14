FROM alpine/helm:latest

ARG PLUTO_VERSION=5.4.0
ARG KUBECONFORM_VERSION=v0.7.0

RUN wget -q https://github.com/FairwindsOps/pluto/releases/download/v${PLUTO_VERSION}/pluto_${PLUTO_VERSION}_linux_amd64.tar.gz && \
    tar xf pluto_${PLUTO_VERSION}_linux_amd64.tar.gz && \
    cp pluto /usr/bin

RUN wget -q https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz \
  && tar -xf kubeconform-linux-amd64.tar.gz && \
  mv kubeconform /usr/local/bin/kubeconform

ENTRYPOINT ["/bin/sh", "-c"]

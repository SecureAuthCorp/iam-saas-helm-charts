# Cloudentity Authorization CD

[Cloudentity](https://cloudentity.com/) Authorization Control Plane (ACP) is a cutting edge platform for the API access control. ACP consolidates capabilities of a modern OAuth/OIDC server with an advanced authorization, consent management, and developer enablement.

ACP-CD provides a mechanism allowing you to declaratively manage the configuration of your ACP data.
It allows to set up policies, APIs, clients, services, and all other features of ACP by defining those in a file.
It can be used to set up a GitOps-like pipeline, or ad-hoc import, easing the process.
This chart bootstraps [acp-cd](https://docs.authorization.cloudentity.com/guides/developer/protect/istio/configuration_import/) 
deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.16+
- Helm 3+

## Get Repo Info

```console
helm repo add acp https://charts.cloudentity.io
helm repo update
```

_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._

## Install Chart

```console
# Helm
$ helm install [RELEASE_NAME] acp/acp-cd
```

_See [configuration](#configuration) below._

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

## Uninstall Chart

```console
# Helm
$ helm uninstall [RELEASE_NAME]
```

This removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._

## Upgrading Chart

```console
# Helm
$ helm upgrade [RELEASE_NAME] [CHART] --install
```

_See [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) for command documentation._

## Configuration

See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments, visit the chart's [values.yaml](./values.yaml), or run these configuration commands:

```console
$ helm show values acp/acp-cd
```

You may similarly use the above configuration commands on each chart [dependency](#dependencies) to see it's configurations.

### Docker Pull Credentials

The acp-cd Job runs a Pod that uses a Secret to pull an image from a private Docker registry, please refer to the documentation for that mechanism ([Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/))

To manually configure Docker credentials, first create a Secret by providing credentials on the command line:

```console
kubectl create secret docker-registry docker.secureauth.com --docker-server=docker.secureauth.com --docker-username=<your-name> --docker-password=<your-password>
```

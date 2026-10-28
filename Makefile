### VARIABLES ###

# name of the chart on which targets will be perfomed
CHART ?= acp

# name of the Kubernetes Namespace where resources will be placed
NAMESPACE ?= acp-system

# list of helm charts that should match ACP release version
HELM_CHARTS = acp-cd,acp,istio-authorizer,kube-acp-stack

# istio version
ISTIO_VERSION ?= 1.26.0

# ACP helm chart version
ACP_VERSION ?= 2.29.0
export ACP_VERSION

# ACP image tag deployed by the tests; empty = chart appVersion, latest = ciam-core dev tip
ACP_IMAGE_TAG ?=

# published chart repo the upgrade test starts from before upgrading to ./charts/acp
ACP_CHART_REPO ?= https://charts.cloudentity.io
ACP_CHART_REPO_NAME ?= acp-published
export ACP_CHART_REPO

### TARGETS ###

# main targets
prepare: create-cluster install-base-stack

prepare-published: create-cluster install-published-stack

upgrade: clean-helm install-base-stack rollout-status

install: helm-install

uninstall: helm-uninstall

verify: wait

test: helm-test

clean: delete-cluster clean-helm

# auxiliaries
create-cluster:
	kind create cluster \
		--name acp-helm-charts \
		--config tests/config/kind.yaml
	kubectl create namespace ${NAMESPACE}
	kubectl create secret docker-registry docker.secureauth.com \
		--namespace ${NAMESPACE} \
		--docker-server=docker.secureauth.com \
		--docker-username=${DOCKER_USER} \
		--docker-password=${DOCKER_PWD}

install-base-stack:
	mkdir --parents .kube-acp-stack-test
	cp ./charts/kube-acp-stack/Chart.yaml ./charts/kube-acp-stack/values.yaml .kube-acp-stack-test/
	yq eval '(.dependencies[]|select(.name == "acp").repository) |= "file://../charts/acp"' .kube-acp-stack-test/Chart.yaml --inplace
	helm dependency update .kube-acp-stack-test
	helm upgrade acp .kube-acp-stack-test \
		--values ./tests/config/kube-acp-stack.yaml \
		${if ${strip ${ACP_IMAGE_TAG}},--set-string acp.image.tag=${strip ${ACP_IMAGE_TAG}}} \
		--namespace ${NAMESPACE} \
		--timeout 10m \
		--install

add-chart-repo:
	helm repo add $(ACP_CHART_REPO_NAME) $(ACP_CHART_REPO) --force-update
	helm repo update $(ACP_CHART_REPO_NAME)

install-published-stack: add-chart-repo
	mkdir --parents .kube-acp-stack-test
	cp ./charts/kube-acp-stack/Chart.yaml ./charts/kube-acp-stack/values.yaml .kube-acp-stack-test/
	PUBLISHED_ACP_VERSION=$$(helm search repo $(ACP_CHART_REPO_NAME)/acp --versions --output json \
		--version "<=$$(yq '.version' ./charts/acp/Chart.yaml)" \
		| jq --raw-output 'map(select(.name == "$(ACP_CHART_REPO_NAME)/acp")) | first | .version') \
	&& test "$$PUBLISHED_ACP_VERSION" != null \
	&& echo "published acp chart version: $$PUBLISHED_ACP_VERSION" \
	&& PUBLISHED_ACP_VERSION=$$PUBLISHED_ACP_VERSION yq eval \
		'(.dependencies[]|select(.name == "acp")) |= (.repository = strenv(ACP_CHART_REPO) | .version = strenv(PUBLISHED_ACP_VERSION))' \
		.kube-acp-stack-test/Chart.yaml --inplace
	helm dependency update .kube-acp-stack-test
	helm upgrade acp .kube-acp-stack-test \
		--values ./tests/config/kube-acp-stack.yaml \
		--namespace ${NAMESPACE} \
		--timeout 10m \
		--install

install-ingress-controller:
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo update
	kubectl create namespace nginx
	helm upgrade \
		--install ingress-nginx ingress-nginx/ingress-nginx \
		--values ./tests/config/ingress-nginx.yaml \
		--namespace nginx
	kubectl --namespace nginx wait deploy/ingress-nginx-controller \
		--for condition=available \
		--timeout=10m

install-istio:
	curl --location https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} TARGET_ARCH=x86_64  sh -
	./istio-${ISTIO_VERSION}/bin/istioctl install --filename ./tests/config/ce-istio-profile.yaml --skip-confirmation
	kubectl label namespace default istio-injection=enabled
	rm --recursive --force ./istio-${ISTIO_VERSION}

install-example-httpbin:
	kubectl apply --filename ./tests/services/httpbin

clean-helm:
	rm --recursive --force .kube-acp-stack-test

delete-cluster:
	kind delete cluster --name acp-helm-charts

docker:
	docker build --tag cloudentity/helm-tools - < Dockerfile

helm-lint:
	helm lint ./charts/${CHART}

lint-kubeconform: docker
	docker run \
		--volume $(shell pwd)/charts/${CHART}:/data \
		--rm \
		cloudentity/helm-tools \
		"helm template 'lint' /data |\
		kubeconform -ignore-missing-schemas"

helm-install:
	helm upgrade ${CHART} ./charts/${CHART} \
		--namespace ${NAMESPACE} \
		--values ./tests/config/${CHART}.yaml \
		--timeout 10m \
		--create-namespace \
		--install

helm-uninstall:
	helm uninstall ${CHART} \
		--namespace ${NAMESPACE}

helm-test:
	helm test ${CHART} --namespace ${NAMESPACE}

wait:
	kubectl wait deploy/${CHART} \
		--for condition=available \
		--namespace ${NAMESPACE} \
		--timeout 10m

deployed-image:
	kubectl get pods \
		--namespace ${NAMESPACE} \
		--selector app.kubernetes.io/name=${CHART} \
		--output jsonpath='{range .items[*]}{.spec.containers[*].image}{" "}{.status.containerStatuses[*].imageID}{"\n"}{end}'

wait-for-daemonset:
	kubectl wait daemonset/${CHART} \
		--for=jsonpath='{.status.numberReady}'=1 \
		--namespace ${NAMESPACE} \
		--timeout 10m

rollout-status:
	kubectl rollout status deploy/${CHART} \
		--namespace ${NAMESPACE} \
		--timeout 10m

release-info: deployed-image
	helm history ${CHART} --namespace ${NAMESPACE}
	kubectl get deploy/${CHART} \
		--namespace ${NAMESPACE} \
		--output jsonpath='{.metadata.labels.helm\.sh/chart}{"\n"}'

debug:
	-kubectl get all --all-namespaces
	-kubectl logs daemonset/kindnet --namespace kube-system
	-kubectl logs daemonset/kube-proxy --namespace kube-system
	-kubectl logs deploy/coredns --namespace kube-system
	-kubectl logs deploy/local-path-provisioner --namespace local-path-storage
	-kubectl logs --selector app.kubernetes.io/name=${CHART} --namespace ${NAMESPACE}
	-kubectl describe pod --selector app.kubernetes.io/name=${CHART} --namespace ${NAMESPACE}

check-kube-apis:
	docker run --rm --volume $(PWD)/charts/${CHART}:/data cloudentity/helm-tools \
		'sed "s/false/true/g" /data/values.yaml |\
		helm template \
		--api-versions "autoscaling/v2/HorizontalPodAutoscaler" \
		--api-versions "networking.k8s.io/v1/Ingress" \
		--api-versions "policy/v1/PodDisruptionBudget" \
		--values - /data |\
		pluto detect --ignore-deprecations --output wide -'

check-acp-charts-version:
	tests/scripts/acp-version-check.sh

update-istio-configmap:
	tests/scripts/update-istio-configmap.sh

bump-acp-version:
	tests/scripts/bump-acp-version.sh ${HELM_CHARTS} ${ACP_VERSION}

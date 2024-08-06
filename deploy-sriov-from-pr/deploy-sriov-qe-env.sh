#!/usr/bin/env bash
set -xeo pipefail

# load variables
REPO=${REPO:-"https://github.com/openshift/sriov-network-operator.git"}
BRANCH=${BRANCH:-"master"}
PR=${PR:-""}

INTERNAL_REGISTRY=${INTERNAL_REGISTRY:-"registry:5000"}
OCP_PULL_SECRET=${OCP_PULL_SECRET:-"/root/openshift_pull"}
INTERNAL_REGISTRY_SECRET=${INTERNAL_REGISTRY_SECRET:-"/root/openshift_pull"}

OPERATOR_NAMESPACE=${OPERATOR_NAMESPACE:-"openshift-sriov-network-operator"}
CATALOG_NAME=${CATALOG_NAME:-"sriov-index"}

CSV_FILE_PATH="manifests/stable/sriov-network-operator.clusterserviceversion.yaml"

# construct image names
INDEX_IMAGE=${INTERNAL_REGISTRY}"/sriov-index:latest"
BUNDLE_IMAGE=${INTERNAL_REGISTRY}"/sriov-bundle:latest"
SRIOV_NETWORK_OPERATOR_IMAGE=${INTERNAL_REGISTRY}"/sriov-network-operator:latest"
SRIOV_NETWORK_CONFIG_DAEMON_IMAGE=${INTERNAL_REGISTRY}"/sriov-network-config-daemon:latest"
SRIOV_NETWORK_WEBHOOK_IMAGE=${INTERNAL_REGISTRY}"/sriov-network-webhook:latest"


# clean up everything
echo "clean repo folder"
rm -rf sriov-network-operator || true

echo "clean index image"
oc -n openshift-marketplace delete catalogsource ${CATALOG_NAME} || true

echo "clean sriov namespace"
oc delete ns $OPERATOR_NAMESPACE --wait=false || true
sleep 3

echo "remove webhooks"
oc delete mutatingwebhookconfigurations.admissionregistration.k8s.io sriov-operator-webhook-config || true
oc delete mutatingwebhookconfigurations.admissionregistration.k8s.io network-resources-injector-config || true
oc delete validatingwebhookconfigurations.admissionregistration.k8s.io sriov-operator-webhook-config || true

echo "delete sriov crds"
oc get crd | grep sriovnetwork.openshift.io | awk '{print "oc delete crd",$1}' | sh || true

echo "wait for ${OPERATOR_NAMESPACE} namespace to get removed"
ATTEMPTS=0
MAX_ATTEMPTS=72
ready=false
sleep_time=5
until $ready || [ $ATTEMPTS -eq $MAX_ATTEMPTS ]
do
    echo "waiting for ${OPERATOR_NAMESPACE} namespace to be removed"
    if [ `oc get ns | grep ${OPERATOR_NAMESPACE} | wc -l` == 0 ]; then
        echo "${OPERATOR_NAMESPACE} namespace removed}"
        ready=true
    else
        echo "${OPERATOR_NAMESPACE} namespace not removed yet, waiting..."
        sleep $sleep_time
    fi
    ATTEMPTS=$((ATTEMPTS+1))
done

# clone the repo
git clone $REPO -b $BRANCH --single-branch

# access repo
cd sriov-network-operator

# if a PR is configured switch to the PR
if [ -n "$PR" ]; then
  echo "cloning sriov repo from PR ${PR}"
  git fetch origin pull/$PR/head:pr
  git checkout pr
fi

mkdir bin || true

EXTERNAL_IMAGES_TAG=`cat manifests/stable/sriov-network-operator.clusterserviceversion.yaml | grep "containerImage: quay.io/openshift/origin-sriov-network-operator" | awk -F':' '{print $NF}'`

EXTERNAL_SRIOV_NETWORK_OPERATOR_IMAGE="quay.io/openshift/origin-sriov-network-operator:${EXTERNAL_IMAGES_TAG}"
EXTERNAL_SRIOV_NETWORK_CONFIG_DAEMON_IMAGE="quay.io/openshift/origin-sriov-network-config-daemon:${EXTERNAL_IMAGES_TAG}"
EXTERNAL_SRIOV_NETWORK_WEBHOOK_IMAGE="quay.io/openshift/origin-sriov-network-webhook:${EXTERNAL_IMAGES_TAG}"

# external images to the repo
# use latest to internal sync always to make the imagePullPolicy always
EXTERNAL_SRIOV_CNI_IMAGE="quay.io/openshift/origin-sriov-cni:${EXTERNAL_IMAGES_TAG}"
SRIOV_CNI_IMAGE=${INTERNAL_REGISTRY}"/sriov-cni:latest"

EXTERNAL_SRIOV_DEVICE_PLUGIN_IMAGE="quay.io/openshift/origin-sriov-network-device-plugin:${EXTERNAL_IMAGES_TAG}"
SRIOV_DEVICE_PLUGIN_IMAGE=${INTERNAL_REGISTRY}"/sriov-network-device-plugin:latest"

EXTERNAL_SRIOV_DP_WEBHOOK_IMAGE="quay.io/openshift/origin-sriov-dp-admission-controller:${EXTERNAL_IMAGES_TAG}"
SRIOV_DP_WEBHOOK_IMAGE=${INTERNAL_REGISTRY}"/sriov-dp-admission-controller:latest"

EXTERNAL_SRIOV_INFINIBAND_IMAGE="quay.io/openshift/origin-sriov-infiniband-cni:${EXTERNAL_IMAGES_TAG}"
SRIOV_INFINIBAND_IMAGE=${INTERNAL_REGISTRY}"/sriov-infiniband-cni:latest"

EXTERNAL_RDMA_IMAGE="quay.io/openshift/origin-rdma-cni:${EXTERNAL_IMAGES_TAG}"
RDMA_IMAGE=${INTERNAL_REGISTRY}"/rdma-cni:latest"

# download opm
REDHAT_BUGZILLA_PRODUCT_VERSION=`cat /etc/os-release | grep REDHAT_BUGZILLA_PRODUCT_VERSION`
MAJOR_VERSION=${REDHAT_BUGZILLA_PRODUCT_VERSION%%.*}
if (( MAJOR_VERSION > 8 )); then
    curl -L https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.16/opm-linux.tar.gz | tar xvz -C bin
    mv bin/opm-rhel8 bin/opm
else
    curl -L https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.12/opm-linux.tar.gz | tar xvz -C bin
fi

# build containers from the sriov repo
echo "## build operator image"
podman build --authfile=${OCP_PULL_SECRET} -t "${SRIOV_NETWORK_OPERATOR_IMAGE}" -f "Dockerfile.rhel7" .

echo "## build daemon image"
podman build --authfile=${OCP_PULL_SECRET} -t "${SRIOV_NETWORK_CONFIG_DAEMON_IMAGE}" -f "Dockerfile.sriov-network-config-daemon.rhel7" .

echo "## build webhook image"
podman build --authfile=${OCP_PULL_SECRET} -t "${SRIOV_NETWORK_WEBHOOK_IMAGE}" -f "Dockerfile.webhook.rhel7" .

echo "## push operator image"
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${SRIOV_NETWORK_OPERATOR_IMAGE}
echo "## push daemon image"
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${SRIOV_NETWORK_CONFIG_DAEMON_IMAGE}
echo "## push webhook image"
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${SRIOV_NETWORK_WEBHOOK_IMAGE}

# pull tag and push external images for sriov operator
podman pull --authfile=${OCP_PULL_SECRET} ${EXTERNAL_SRIOV_CNI_IMAGE}
podman tag ${EXTERNAL_SRIOV_CNI_IMAGE} ${SRIOV_CNI_IMAGE}
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${SRIOV_CNI_IMAGE}

podman pull --authfile=${OCP_PULL_SECRET} ${EXTERNAL_SRIOV_DEVICE_PLUGIN_IMAGE}
podman tag ${EXTERNAL_SRIOV_DEVICE_PLUGIN_IMAGE} ${SRIOV_DEVICE_PLUGIN_IMAGE}
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${SRIOV_DEVICE_PLUGIN_IMAGE}

podman pull --authfile=${OCP_PULL_SECRET} ${EXTERNAL_SRIOV_DP_WEBHOOK_IMAGE}
podman tag ${EXTERNAL_SRIOV_DP_WEBHOOK_IMAGE} ${SRIOV_DP_WEBHOOK_IMAGE}
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${SRIOV_DP_WEBHOOK_IMAGE}

podman pull --authfile=${OCP_PULL_SECRET} ${EXTERNAL_SRIOV_INFINIBAND_IMAGE}
podman tag ${EXTERNAL_SRIOV_INFINIBAND_IMAGE} ${SRIOV_INFINIBAND_IMAGE}
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${SRIOV_INFINIBAND_IMAGE}

# rdma-cni images doesn't exist in older sriov operator versions
if [ `cat ${CSV_FILE_PATH} | grep ${EXTERNAL_RDMA_IMAGE} | wc -l` == 1 ]; then
  podman pull --authfile=${OCP_PULL_SECRET} ${EXTERNAL_RDMA_IMAGE}
  podman tag ${EXTERNAL_RDMA_IMAGE} ${RDMA_IMAGE}
  podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${RDMA_IMAGE}
fi

# switch images in csv
sed -i "s|${EXTERNAL_SRIOV_NETWORK_OPERATOR_IMAGE}|${SRIOV_NETWORK_OPERATOR_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|${EXTERNAL_SRIOV_NETWORK_CONFIG_DAEMON_IMAGE}|${SRIOV_NETWORK_CONFIG_DAEMON_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|${EXTERNAL_SRIOV_NETWORK_WEBHOOK_IMAGE}|${SRIOV_NETWORK_WEBHOOK_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|${EXTERNAL_SRIOV_CNI_IMAGE}|${SRIOV_CNI_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|${EXTERNAL_SRIOV_DEVICE_PLUGIN_IMAGE}|${SRIOV_DEVICE_PLUGIN_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|${EXTERNAL_SRIOV_DP_WEBHOOK_IMAGE}|${SRIOV_DP_WEBHOOK_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|${EXTERNAL_SRIOV_INFINIBAND_IMAGE}|${SRIOV_INFINIBAND_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|${EXTERNAL_RDMA_IMAGE}|${RDMA_IMAGE}|" ${CSV_FILE_PATH}
sed -i "s|IfNotPresent|Always|" ${CSV_FILE_PATH}

# build bundle
echo "## build bundle"
podman build -t "${BUNDLE_IMAGE}" -f "bundleci.Dockerfile" .
echo "## push bundle"
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${BUNDLE_IMAGE}

# build index image
echo "## build index image"
bin/opm index add -p podman --bundles ${BUNDLE_IMAGE} --tag ${INDEX_IMAGE}

echo "## push index image"
podman push --authfile=${INTERNAL_REGISTRY_SECRET} ${INDEX_IMAGE}

# create catalogSource
cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${CATALOG_NAME}
  namespace: openshift-marketplace
spec:
  displayName: CI Index
  image: ${INDEX_IMAGE}
  publisher: Red Hat
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 10m0s
---
EOF

# create sriov namespace
cat <<EOF | oc apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-sriov-network-operator
  annotations:
    workload.openshift.io/allowed: management
---
EOF

# create operator group
cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: sriov-network-operators
  namespace: openshift-sriov-network-operator
spec:
  targetNamespaces:
  - openshift-sriov-network-operator
---
EOF

# create subscription
cat <<EOF | oc apply -f -
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: sriov-network-operator-subscription
  namespace: openshift-sriov-network-operator
spec:
  channel: "alpha"
  name: sriov-network-operator
  source: sriov-index
  sourceNamespace: openshift-marketplace
---
EOF

# wait for the operator to get installed
echo "wait for csv to be installed"
ATTEMPTS=0
MAX_ATTEMPTS=72
ready=false
sleep_time=5
until $ready || [ $ATTEMPTS -eq $MAX_ATTEMPTS ]
do
    echo "waiting csv to be installed"
    if [ `oc -n ${OPERATOR_NAMESPACE} get csv | grep sriov-network-operator | grep Succeeded | wc -l` == 1 ]; then
        echo "csv installed}"
        ready=true
    else
        echo "csv not installed yet, waiting..."
        sleep $sleep_time
    fi
    ATTEMPTS=$((ATTEMPTS+1))
done

# apply sriovOperatorConfig
cat <<EOF | oc apply -f -
---
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovOperatorConfig
metadata:
  name: default
  namespace: openshift-sriov-network-operator
spec:
  enableInjector: true
  enableOperatorWebhook: true
  logLevel: 2
  disableDrain: false
---
EOF

echo "Deployment done enjoy :)"
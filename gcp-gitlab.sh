#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# https://github.com/GoogleCloudPlatform/click-to-deploy/blob/master/k8s/gitlab/README.md

SCRIPT_DIR=$(dirname "$0")
export CLUSTER_NAME=gitlab-dev-$(date +%j)-$RANDOM
echo "provisioning cluster ${CLUSTER_NAME}..."
gcloud container clusters create ${CLUSTER_NAME} --flags-file $SCRIPT_DIR/k8s/gcp/config/config.yml

kapp deploy -a app-crd -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml" -y

export APP_INSTANCE_NAME=gitlab-1
export NAMESPACE=gitlab
export METRICS_EXPORTER_ENABLED=false
# export DOMAIN_NAME="rkgcloud.com"

# check latest tag version here https://console.cloud.google.com/artifacts/docker/cloud-marketplace/us/gcr.io/google%2Fgitlab
export TAG="16.3"
# export TAG="17.1.0"
export IMAGE_REGISTRY="marketplace.gcr.io/google"
export IMAGE_GITLAB="${IMAGE_REGISTRY}/gitlab"
export IMAGE_REDIS="${IMAGE_REGISTRY}/gitlab/redis:${TAG}"
export IMAGE_REDIS_EXPORTER="${IMAGE_REGISTRY}/gitlab/redis-exporter:${TAG}"
export IMAGE_POSTGRESQL="${IMAGE_REGISTRY}/gitlab/postgresql:${TAG}"
export IMAGE_POSTGRESQL_EXPORTER="${IMAGE_REGISTRY}/gitlab/postgresql-exporter:${TAG}"
export IMAGE_DEPLOYER="${IMAGE_REGISTRY}/gitlab/deployer:${TAG}"
export IMAGE_METRICS_EXPORTER="${IMAGE_REGISTRY}/gitlab/prometheus-to-sd:${TAG}"

export DEFAULT_STORAGE_CLASS="standard" # provide your StorageClass name if not "standard"
export SSL_CONFIGURATION="Self-signed"
export TLS_CERTIFICATE_KEY="$(cat $SCRIPT_DIR/k8s/gcp/config/tls.key | base64)"
export TLS_CERTIFICATE_CRT="$(cat $SCRIPT_DIR/k8s/gcp/config/tls.crt | base64)"


kapp deploy -a ns -f $SCRIPT_DIR/k8s/gcp/config.yml -y


# openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#     -keyout config/tls.key \
#     -out config/tls.crt \
#     -subj "/CN=rkgcloud.us/O=gitlab"

export GITLAB_SERVICE_ACCOUNT="${APP_INSTANCE_NAME}-serviceaccount"
echo will execute helm install with following args ...\
"${APP_INSTANCE_NAME}" \
--namespace "${NAMESPACE}" \
--set gitlab.image.repo="${IMAGE_GITLAB}" \
--set gitlab.image.tag="${TAG}" \
--set gitlab.rootPassword="${GITLAB_ROOT_PASSWORD}" \
--set gitlab.serviceAccountName="${GITLAB_SERVICE_ACCOUNT}" \
--set gitlab.sslConfiguration="${SSL_CONFIGURATION}" \
--set redis.image="${IMAGE_REDIS}" \
--set redis.exporter.image="${IMAGE_REDIS_EXPORTER}" \
--set redis.password="${REDIS_ROOT_PASSWORD}" \
--set postgresql.image="${IMAGE_POSTGRESQL}" \
--set postgresql.exporter.image="${IMAGE_POSTGRESQL_EXPORTER}" \
--set postgresql.password="${POSTGRES_PASSWORD}" \
--set persistence.storageClass="${DEFAULT_STORAGE_CLASS}" \
--set deployer.image="${IMAGE_DEPLOYER}" \
--set metrics.image="${IMAGE_METRICS_EXPORTER}" \
--set tls.base64EncodedPrivateKey="${TLS_CERTIFICATE_KEY}" \
--set tls.base64EncodedCertificate="${TLS_CERTIFICATE_CRT}" \
$SCRIPT_DIR/k8s/gitlab/chart/gitlab


helm upgrade --install "${APP_INSTANCE_NAME}" \
--namespace "${NAMESPACE}" \
--set gitlab.image.repo="${IMAGE_GITLAB}" \
--set gitlab.image.tag="${TAG}" \
--set gitlab.rootPassword="${GITLAB_ROOT_PASSWORD}" \
--set gitlab.serviceAccountName="${GITLAB_SERVICE_ACCOUNT}" \
--set gitlab.sslConfiguration="${SSL_CONFIGURATION}" \
--set redis.image="${IMAGE_REDIS}" \
--set redis.exporter.image="${IMAGE_REDIS_EXPORTER}" \
--set redis.password="${REDIS_ROOT_PASSWORD}" \
--set postgresql.image="${IMAGE_POSTGRESQL}" \
--set postgresql.exporter.image="${IMAGE_POSTGRESQL_EXPORTER}" \
--set postgresql.password="${POSTGRES_PASSWORD}" \
--set persistence.storageClass="${DEFAULT_STORAGE_CLASS}" \
--set deployer.image="${IMAGE_DEPLOYER}" \
--set metrics.image="${IMAGE_METRICS_EXPORTER}" \
--set tls.base64EncodedPrivateKey="${TLS_CERTIFICATE_KEY}" \
--set tls.base64EncodedCertificate="${TLS_CERTIFICATE_CRT}" \
$SCRIPT_DIR/k8s/gitlab/chart/gitlab



  
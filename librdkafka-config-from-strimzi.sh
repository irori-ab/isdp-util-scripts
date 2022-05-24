#!/bin/bash

#set -o xtrace

if [[ "$#" -lt 3 ]]; then
  echo "usage: sh librdkafka-config-from-strimzi.sh CLUSTER_NAME KAFKA_USER BOOTSTARP_URL [CLUSTER_NAMESPACE=kafka] [CONFIG_BASE_DIR=~/.librdkafka]"
  echo 
  echo "Fetches Strimzi Kafka User mTLS secrets and creates a librdkafka config file, for use e.g. with kcat. Assumes "
  echo "current kubectl context should be used (set with KUBECONFIG)."
  exit 1
fi


CLUSTER_NAME=$1
KAFKA_USER=$2
BOOTSTRAP_URL=${3}
CLUSTER_NAMESPACE=${4:-kafka}
BASE_DIR=${5:-~/.librdkafka}

mkdir -p $BASE_DIR

CONFIG_FILE_PATH=${BASE_DIR}/$CLUSTER_NAME.$KAFKA_USER.cfg


kubectl get secret -n $CLUSTER_NAMESPACE ${CLUSTER_NAME}-cluster-ca-cert -o=go-template='{{index .data "ca.crt"}}' | base64 -d \
  > ${BASE_DIR}/$CLUSTER_NAME.cluster.crt

CLUSTER_KS_PW=$(kubectl get secret -n $CLUSTER_NAMESPACE ${CLUSTER_NAME}-cluster-ca-cert -o=go-template='{{index .data "ca.password"}}' | base64 -d)


kubectl get secret -n $CLUSTER_NAMESPACE ${KAFKA_USER} -o=go-template='{{index .data "user.p12"}}' | base64 -d \
  > ${BASE_DIR}/$CLUSTER_NAME.$KAFKA_USER.user.p12

USER_KS_PW=$(kubectl get secret -n $CLUSTER_NAMESPACE ${KAFKA_USER} -o=go-template='{{index .data "user.password"}}' | base64 -d)


cat << EOF > $CONFIG_FILE_PATH
bootstrap.servers=$BOOTSTRAP_URL
security.protocol=ssl
ssl.keystore.location=${BASE_DIR}/$CLUSTER_NAME.$KAFKA_USER.user.p12
ssl.keystore.password=$USER_KS_PW
ssl.ca.location=${BASE_DIR}/$CLUSTER_NAME.cluster.crt
EOF

cat << EOF
Set the config with:
export KCAT_CONFIG=$CONFIG_FILE_PATH
EOF


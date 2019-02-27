#!/bin/bash
export BASEDIR=$(dirname $0)/../..
source "${BASEDIR}/hack/init.sh"
versionWithBuildNumber="$(newVersionWithBuildNumber)"

docker build -t rocketmqinc/rocketmq-operator:${versionWithBuildNumber} .
docker push rocketmqinc/rocketmq-operator:${versionWithBuildNumber}
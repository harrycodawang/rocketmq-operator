# Include the script for test
BASEDIR=$(dirname $0)/../..
source "${BASEDIR}/test/lib/util.sh"

bash "${BASEDIR}/test/e2e/03-create-cluster.sh"
sleep 5
bash "${BASEDIR}/test/e2e/04-pubsub.sh"
bash "${BASEDIR}/test/e2e/05-update-brokerImage.sh"
bash "${BASEDIR}/test/e2e/04-pubsub.sh"
bash "${BASEDIR}/test/e2e/06-scale-groupReplicas.sh"
bash "${BASEDIR}/test/e2e/04-pubsub.sh"
bash "${BASEDIR}/test/e2e/07-delete-cluster.sh"







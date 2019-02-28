# Include the script for test
BASEDIR=$(dirname $0)/../..
source "${BASEDIR}/test/lib/util.sh"

echo "NAMESRV_ADDR=$NAMESRV_ADDR, please verify setting the correct NAMESRV_ADDR"
kubectl create -f ${BASEDIR}/deploy/03-deploymentWithConfig.yaml
util::test::try_until_text 'kubectl get po' 'operator.* Running' "20000" "1"







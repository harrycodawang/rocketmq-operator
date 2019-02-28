# Include the script for test
BASEDIR=$(dirname $0)/../..
echo ${BASEDIR}
source "${BASEDIR}/test/lib/util.sh"

kubectl delete -f ${BASEDIR}/deploy/03-deploymentWithConfig.yaml
util::test::try_until_not_text 'kubectl get po' 'operator.* Running' "20000" "1"







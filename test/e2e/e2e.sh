# Include the script for test
BASEDIR=$(dirname $0)/../..
echo ${BASEDIR}
source "${BASEDIR}/test/lib/util.sh"

util::test::expect_success_and_text 'kubectl get node' 'master'
util::test::expect_success_and_text 'kubectl get deploy' 'rocketmq'

util::test::expect_success_and_text 'kubectl get po' 'rocketmq-operator.* Running'

util::test::expect_success_and_text 'kubectl scale --replicas=0 deploy/rocketmq-operator' 'scaled'
util::test::try_until_not_text 'kubectl get po' 'rocketmq-operator.* Running' "10000" "1"  

util::test::expect_success_and_text 'kubectl scale --replicas=1 deploy/rocketmq-operator' 'scaled'
util::test::try_until_text 'kubectl get po' 'rocketmq-operator.* Running' "10000" "1" 








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

util::test::expect_success_and_text 'kubectl create -f deploy/04-minikube-1m.yaml' 'created'
util::test::try_until_text 'kubectl get po' 'mybrokercluster.* Running' "20000" "1"

kubectl patch BrokerCluster mybrokercluster --type='merge' -p '{"spec":{"groupReplica":2}}'
util::test::try_until_text 'kubectl get po' 'mybrokercluster-1.* Running' "60000" "1"

util::test::expect_success_and_text 'kubectl delete -f deploy/04-minikube-1m.yaml' 'deleted'
util::test::try_until_text 'kubectl get po' 'mybrokercluster.* Terminating' "20000" "1"
util::test::try_until_not_text 'kubectl get po' 'mybrokercluster' "60000" "1"








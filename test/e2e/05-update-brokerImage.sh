# Include the script for test
BASEDIR=$(dirname $0)/../..
echo ${BASEDIR}
source "${BASEDIR}/test/lib/util.sh"

util::text::print_red_bold "Change RocketMQ image from 4.3.2 to 4.3.1..."
kubectl get sts mybrokercluster-0 -o yaml | sed s/rocketmq:4\.3\.2-k8s/rocketmq:4\.3\.1-k8s/g | kubectl replace -f -
util::test::try_until_text 'kubectl get po' 'mybrokercluster-0.* Terminating' "60000" "1"
util::test::try_until_text 'kubectl get po' 'mybrokercluster-0.* ContainerCreating' "60000" "1"
util::test::try_until_text 'kubectl get po' 'mybrokercluster-0.* Running' "60000" "1"

util::text::print_red_bold "Change RocketMQ image from 4.3.1 to 4.3.2..."
#kubectl patch po mybrokercluster-0-0 --type='merge' -p '{"spec":{"containers[*]":[{"image":"rocketmqinc/rocketmq:4.3.3-k8s"}]}}'
kubectl get sts mybrokercluster-0 -o yaml | sed s/rocketmq:4\.3\.1-k8s/rocketmq:4\.3\.2-k8s/g | kubectl replace -f -
util::test::try_until_text 'kubectl get po' 'mybrokercluster-0.* Terminating' "60000" "1"
util::test::try_until_text 'kubectl get po' 'mybrokercluster-0.* ContainerCreating' "60000" "1"
util::test::try_until_text 'kubectl get po' 'mybrokercluster-0.* Running' "60000" "1"








# Include the script for test
BASEDIR=$(dirname $0)/../..
source "${BASEDIR}/test/lib/util.sh"

# Warm up
kubectl exec -ti mybrokercluster-0-0 -- sh -c '/opt/rocketmq-4.3.2/bin/mqadmin clusterList -n $NAMESRV_ADDRESS | tee /result.log'
util::text::print_red_bold "Test clusterList..."
echo "NAMESRV_ADDR=$NAMESRV_ADDR, please verify setting the correct NAMESRV_ADDR"
kubectl exec -ti mybrokercluster-0-0 -- sh -c '/opt/rocketmq-4.3.2/bin/mqadmin clusterList -n $NAMESRV_ADDRESS | tee /result.log'
util::test::expect_success_and_text 'kubectl exec -ti mybrokercluster-0-0 cat /result.log' 'DefaultCluster'

util::text::print_red_bold "Test topicList..."
kubectl exec -ti mybrokercluster-0-0 -- sh -c '/opt/rocketmq-4.3.2/bin/mqadmin topicList -n $NAMESRV_ADDRESS | tee /result.log'
util::test::expect_success_and_text 'kubectl exec -ti mybrokercluster-0-0 cat /result.log' 'SELF_TEST_TOPIC'

util::text::print_red_bold "Test sendMessage..."
kubectl exec -ti mybrokercluster-0-0 -- sh -c '/opt/rocketmq-4.3.2/bin/mqadmin sendMessage -t SELF_TEST_TOPIC -p MessageValue -n $NAMESRV_ADDRESS | tee /result.log'
util::test::expect_success_and_text 'kubectl exec -ti mybrokercluster-0-0 cat /result.log' 'SEND_OK'

util::text::print_red_bold "Test consumeMessage..."
kubectl exec -ti mybrokercluster-0-0 -- sh -c '/opt/rocketmq-4.3.2/bin/mqadmin consumeMessage -t SELF_TEST_TOPIC -c 1 -n $NAMESRV_ADDRESS | tee /result.log'
util::test::try_until_text 'kubectl exec -ti mybrokercluster-0-0 cat /result.log' 'MessageValue' "20000" "1"
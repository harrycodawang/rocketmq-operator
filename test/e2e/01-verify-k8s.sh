# Include the script for test
BASEDIR=$(dirname $0)/../..
source "${BASEDIR}/test/lib/util.sh"

util::test::expect_success_and_text 'kubectl get node' 'master'
util::test::expect_success_and_text 'kubectl get deploy' 'rocketmq'








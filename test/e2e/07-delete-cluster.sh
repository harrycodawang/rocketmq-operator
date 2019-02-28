# Include the script for test
BASEDIR=$(dirname $0)/../..
source "${BASEDIR}/test/lib/util.sh"

util::text::print_red_bold "Test delete broker cluster..."
util::test::expect_success_and_text 'kubectl delete -f deploy/04-minikube-1m.yaml' 'deleted'
util::test::try_until_text 'kubectl get po' 'mybrokercluster.* Terminating' "20000" "1"
util::test::try_until_not_text 'kubectl get po' 'mybrokercluster' "60000" "1"








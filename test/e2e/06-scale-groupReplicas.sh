# Include the script for test
BASEDIR=$(dirname $0)/../..
echo ${BASEDIR}
source "${BASEDIR}/test/lib/util.sh"

util::text::print_red_bold "Scale broker groups..."
kubectl patch BrokerCluster mybrokercluster --type='merge' -p '{"spec":{"groupReplica":2}}'
util::test::try_until_text 'kubectl get po' 'mybrokercluster-1.* Running' "60000" "1"

#kubectl patch BrokerCluster mybrokercluster --type='merge' -p '{"spec":{"groupReplica":1}}'
#util::test::try_until_not_text 'kubectl get po' 'mybrokercluster-1.* Running' "60000" "1"








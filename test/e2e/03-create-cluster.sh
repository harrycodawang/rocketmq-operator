# Include the script for test
BASEDIR=$(dirname $0)/../..
source "${BASEDIR}/test/lib/util.sh"

util::text::print_red_bold "Test create broker cluster..."
echo "NAMESRV_ADDR=$NAMESRV_ADDR, please verify setting the correct NAMESRV_ADDR"
cat deploy/04-minikube-1m.yaml | sed s/\$NAMESRV_ADDR/$NAMESRV_ADDR/ | kubectl create -f -
util::test::try_until_text 'kubectl get po' 'mybrokercluster.* Running' "20000" "1"








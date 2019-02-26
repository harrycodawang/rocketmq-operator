# Include the script for test
BASEDIR=$(dirname $0)/../..
echo ${BASEDIR}
source "${BASEDIR}/test/lib/util.sh"

#util::test::internal::success_func 0
#echo $?
#util::test::internal::success_func 1
#echo $?
#util::test::internal::failure_func 0
#echo $?
#util::test::internal::failure_func 1
#echo $?

#util::test::internal::init_tempdir

#util::test::internal::seconds_since_epoch

# Test run_collecting_output and print_results
#cmd_result=$( util::test::internal::run_collecting_output "${1}"; echo $? )
#util::test::internal::print_results
#echo "get_results"
#util::test::internal::get_results

#util::text::print_red_bold 'Hello world!'

#util::test::expect_success 'ls /'
#util::test::expect_failure 'ls /notexists'

#util::test::expect_success 'ls /notexists'
#util::test::expect_failure 'ls /'

util::test::expect_success_and_text 'ls /' 'System'
util::test::expect_success_and_text 'ls /' 'Systems'

util::test::expect_failure_and_text 'ls /notexists' 'file'
util::test::expect_failure_and_text 'ls /notexists' 'xxxxxx'








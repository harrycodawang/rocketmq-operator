#!/bin/bash

# In order to harvest stderr and stdout at the same time into different buckets, we need to stick them into files
# in an intermediate step
os_cmd_internal_tmpdir="${TMPDIR:-"/tmp"}/testtmp"
os_cmd_internal_tmpout="${os_cmd_internal_tmpdir}/tmp_stdout.log"
os_cmd_internal_tmperr="${os_cmd_internal_tmpdir}/tmp_stderr.log"

# util::test::internal::expect_exit_code_run_grep runs the provided test command and expects a specific
# exit code from that command as well as the success of a specified `grep` invocation. Output from the
# command to be tested is suppressed unless either `VERBOSE=1` or the test fails. This function bypasses
# any error exiting settings or traps set by upstream callers by masking the return code of the command
# with the return code of setting the result variable on failure.
#
# Globals:
#  - JUNIT_REPORT_OUTPUT
#  - VERBOSE
# Arguments:
#  - 1: the command to run
#  - 2: command evaluation assertion to use
#  - 3: text to test for
#  - 4: text assertion to use
# Returns:
#  - 0: if all assertions met
#  - 1: if any assertions fail
function util::test::internal::expect_exit_code_run_grep() {
	local cmd=$1
	# default expected cmd code to 0 for success
	local cmd_eval_func=${2:-util::test::internal::success_func}
	# default to nothing
	local grep_args=${3:-}
	# default expected test code to 0 for success
	local test_eval_func=${4:-util::test::internal::success_func}

	local -a junit_log

	util::test::internal::init_tempdir
	# declare_test_start

	local name=$(util::test::internal::describe_call "${cmd}" "${cmd_eval_func}" "${grep_args}" "${test_eval_func}")
	local preamble="Running ${name}..."
	echo "${preamble}"
	# for ease of parsing, we want the entire declaration on one line, so we replace '\n' with ';'
	junit_log+=( "${name//$'\n'/;}" )

	local start_time=$(util::test::internal::seconds_since_epoch)

	local cmd_result=$( util::test::internal::run_collecting_output "${cmd}"; echo $? )
	local cmd_succeeded=$( ${cmd_eval_func} "${cmd_result}"; echo $? )

	local test_result=0
	if [[ -n "${grep_args}" ]]; then
		test_result=$( util::test::internal::run_collecting_output 'grep -Eq "${grep_args}" <(util::test::internal::get_results)'; echo $? )
	fi
	local test_succeeded=$( ${test_eval_func} "${test_result}"; echo $? )

	local end_time=$(util::test::internal::seconds_since_epoch)
	local time_elapsed=$(echo "scale=3; ${end_time} - ${start_time}" | bc | xargs printf '%5.3f') # in decimal seconds, we need leading zeroes for parsing later

	# clear the preamble so we can print out the success or error message
	util::text::clear_string "${preamble}"

	local return_code
	if (( cmd_succeeded && test_succeeded )); then
		util::text::print_green "SUCCESS after ${time_elapsed}s: ${name}"
		junit_log+=( "SUCCESS after ${time_elapsed}s: ${name//$'\n'/;}" )

		if [[ -n ${VERBOSE-} ]]; then
			util::test::internal::print_results
		fi
		return_code=0
	else
		local cause=$(util::test::internal::assemble_causes "${cmd_succeeded}" "${test_succeeded}")

		util::text::print_red_bold "FAILURE after ${time_elapsed}s: ${name}: ${cause}"
		junit_log+=( "FAILURE after ${time_elapsed}s: ${name//$'\n'/;}: ${cause}" )

		util::text::print_red "$(util::test::internal::print_results)"
		return_code=1
	fi

	junit_log+=( "$(util::test::internal::print_results)" )
	# append inside of a subshell so that IFS doesn't get propagated out
	( IFS=$'\n'; echo "${junit_log[*]}" >> "${JUNIT_REPORT_OUTPUT:-/dev/null}" )
	# declare_test_end
	return "${return_code}"
}
readonly -f util::test::internal::expect_exit_code_run_grep

# util::test::internal::init_tempdir initializes the temporary directory
function util::test::internal::init_tempdir() {
	mkdir -p "${os_cmd_internal_tmpdir}"
	rm -f "${os_cmd_internal_tmpdir}"/tmp_std{out,err}.log
}
readonly -f util::test::internal::init_tempdir

# util::test::internal::success_func determines if the input exit code denotes success
# this function returns 0 for false and 1 for true to be compatible with arithmetic tests
function util::test::internal::success_func() {
	local exit_code=$1

	# use a negated test to get output correct for (( ))
	[[ "${exit_code}" -ne "0" ]]
	return $?
}

# util::test::internal::failure_func determines if the input exit code denotes failure
# this function returns 0 for false and 1 for true to be compatible with arithmetic tests
function util::test::internal::failure_func() {
	local exit_code=$1

	# use a negated test to get output correct for (( ))
	[[ "${exit_code}" -eq "0" ]]
	return $?
}

# util::test::internal::describe_call determines the file:line of the latest function call made
# from outside of this file in the call stack, and the name of the function being called from
# that line, returning a string describing the call
function util::test::internal::describe_call() {
	local cmd=$1
	local cmd_eval_func=$2
	local grep_args=${3:-}
	local test_eval_func=${4:-}

	local caller_id=$(util::test::internal::determine_caller)
	local full_name="${caller_id}: executing '${cmd}'"

	local cmd_expectation=$(util::test::internal::describe_expectation "${cmd_eval_func}")
	local full_name="${full_name} expecting ${cmd_expectation}"

	if [[ -n "${grep_args}" ]]; then
		local text_expecting=
		case "${test_eval_func}" in
		"util::test::internal::success_func")
			text_expecting="text" ;;
		"util::test::internal::failure_func")
			text_expecting="not text" ;;
		esac
		full_name="${full_name} and ${text_expecting} '${grep_args}'"
	fi

	echo "${full_name}"
}
readonly -f util::test::internal::describe_call

# util::test::internal::determine_caller determines the file relative to the root directory
# and line number of the function call to the outer util::test wrapper function
function util::test::internal::determine_caller() {
	local call_depth=

	local len_sources="${#BASH_SOURCE[@]}"
	for (( i=0; i<${len_sources}; i++ )); do
		if [ ! $(echo "${BASH_SOURCE[i]}" | grep "lib/util\.sh$") ]; then
			call_depth=i
			break
		fi
	done

	local caller_file="${BASH_SOURCE[${call_depth}]}"
    #caller_file="$( util::repository_relative_path "${caller_file}" )"
	local caller_line="${BASH_LINENO[${call_depth}-1]}"
	echo "${caller_file}:${caller_line}"
}
readonly -f util::test::internal::determine_caller

# util::test::internal::describe_expectation describes a command return code evaluation function
function util::test::internal::describe_expectation() {
	local func=$1
	case "${func}" in
	"util::test::internal::success_func")
		echo "success" ;;
	"util::test::internal::failure_func")
		echo "failure" ;;
	"util::test::internal::specific_code_func"*[0-9])
		local code=$(echo "${func}" | grep -Eo "[0-9]+$")
		echo "exit code ${code}" ;;
	"")
		echo "any result"
	esac
}
readonly -f util::test::internal::describe_expectation

# util::test::internal::seconds_since_epoch returns the number of seconds elapsed since the epoch
# with milli-second precision
function util::test::internal::seconds_since_epoch() {
	local ns=$(date +%s%N)
	# if `date` doesn't support nanoseconds, return second precision
	if [[ "$ns" == *N ]]; then
		date "+%s.000"
		return
	fi
	echo $(bc <<< "scale=3; ${ns}/1000000000")
}
readonly -f util::test::internal::seconds_since_epoch

# util::test::internal::run_collecting_output runs the command given, piping stdout and stderr into
# the given files, and returning the exit code of the command
function util::test::internal::run_collecting_output() {
	local cmd=$1

	local result=
	$( eval "${cmd}" 1>>"${os_cmd_internal_tmpout}" 2>>"${os_cmd_internal_tmperr}" ) || result=$?
	local result=${result:-0} # if we haven't set result yet, the command succeeded

	return "${result}"
}

# util::test::internal::print_results pretty-prints the stderr and stdout files. If attempt separators
# are present, this function returns a concise view of the stdout and stderr output files using a
# timeline format, where consecutive output lines that are the same are condensed into one line
# with a counter
function util::test::internal::print_results() {
	if [[ -s "${os_cmd_internal_tmpout}" ]]; then
		echo "Standard output from the command:"
		if grep -q $'\x1e' "${os_cmd_internal_tmpout}"; then
			util::test::internal::compress_output "${os_cmd_internal_tmpout}"
		else
			cat "${os_cmd_internal_tmpout}"; echo
		fi
	else
		echo "There was no output from the command."
	fi

	if [[ -s "${os_cmd_internal_tmperr}" ]]; then
		echo "Standard error from the command:"
		if grep -q $'\x1e' "${os_cmd_internal_tmperr}"; then
			util::test::internal::compress_output "${os_cmd_internal_tmperr}"
		else
			cat "${os_cmd_internal_tmperr}"; echo
		fi
	else
		echo "There was no error output from the command."
	fi
}
readonly -f util::test::internal::print_results

# util::test::internal::compress_output compresses an output file into timeline representation
function util::test::internal::compress_output() {
	local logfile=$1

	#awk -f ${OS_ROOT}/hack/lib/compress.awk $logfile
  cat "${os_cmd_internal_tmperr}"; echo
}
readonly -f util::test::internal::compress_output

function util::test::expect_success() {
	if [[ $# -ne 1 ]]; then echo "util::test::expect_success expects only one argument, got $#"; return 1; fi
	local cmd=$1

	util::test::internal::expect_exit_code_run_grep "${cmd}"
}
readonly -f util::test::expect_success

# expect_failure runs the cmd and expects a non-zero exit code
function util::test::expect_failure() {
	if [[ $# -ne 1 ]]; then echo "util::test::expect_failure expects only one argument, got $#"; return 1; fi
	local cmd=$1

	util::test::internal::expect_exit_code_run_grep "${cmd}" "util::test::internal::failure_func"
}
readonly -f util::test::expect_failure

# expect_success_and_text runs the cmd and expects an exit code of 0
# as well as running a grep test to find the given string in the output
function util::test::expect_success_and_text() {
	if [[ $# -ne 2 ]]; then echo "util::test::expect_success_and_text expects two arguments, got $#"; return 1; fi
	local cmd=$1
	local expected_text=$2

	util::test::internal::expect_exit_code_run_grep "${cmd}" "util::test::internal::success_func" "${expected_text}"
}
readonly -f util::test::expect_success_and_text

# expect_failure_and_text runs the cmd and expects a non-zero exit code
# as well as running a grep test to find the given string in the output
function util::test::expect_failure_and_text() {
	if [[ $# -ne 2 ]]; then echo "util::test::expect_failure_and_text expects two arguments, got $#"; return 1; fi
	local cmd=$1
	local expected_text=$2

	util::test::internal::expect_exit_code_run_grep "${cmd}" "util::test::internal::failure_func" "${expected_text}"
}
readonly -f util::test::expect_failure_and_text

# expect_success_and_not_text runs the cmd and expects an exit code of 0
# as well as running a grep test to ensure the given string is not in the output
function util::test::expect_success_and_not_text() {
	if [[ $# -ne 2 ]]; then echo "util::test::expect_success_and_not_text expects two arguments, got $#"; return 1; fi
	local cmd=$1
	local expected_text=$2

	util::test::internal::expect_exit_code_run_grep "${cmd}" "util::test::internal::success_func" "${expected_text}" "util::test::internal::failure_func"
}
readonly -f util::test::expect_success_and_not_text

# expect_failure_and_not_text runs the cmd and expects a non-zero exit code
# as well as running a grep test to ensure the given string is not in the output
function util::test::expect_failure_and_not_text() {
	if [[ $# -ne 2 ]]; then echo "util::test::expect_failure_and_not_text expects two arguments, got $#"; return 1; fi
	local cmd=$1
	local expected_text=$2

	util::test::internal::expect_exit_code_run_grep "${cmd}" "util::test::internal::failure_func" "${expected_text}" "util::test::internal::failure_func"
}
readonly -f util::test::expect_failure_and_not_text

# util::test::internal::get_results prints the stderr and stdout files
function util::test::internal::get_results() {
	cat "${os_cmd_internal_tmpout}" "${os_cmd_internal_tmperr}"
}
readonly -f util::test::internal::get_results

# util::test::try_until_success runs the cmd in a small interval until either the command succeeds or times out
# the default time-out for util::test::try_until_success is 60 seconds.
# the default interval for util::test::try_until_success is 200ms
function util::test::try_until_success() {
	if [[ $# -lt 1 ]]; then echo "util::test::try_until_success expects at least one arguments, got $#"; return 1; fi
	local cmd=$1
	local duration=${2:-$minute}
	local interval=${3:-0.2}

	util::test::internal::run_until_exit_code "${cmd}" "util::test::internal::success_func" "${duration}" "${interval}"
}
readonly -f util::test::try_until_success

# util::test::try_until_failure runs the cmd until either the command fails or times out
# the default time-out for util::test::try_until_failure is 60 seconds.
function util::test::try_until_failure() {
	if [[ $# -lt 1 ]]; then echo "util::test::try_until_failure expects at least one argument, got $#"; return 1; fi
	local cmd=$1
	local duration=${2:-$minute}
	local interval=${3:-0.2}

	util::test::internal::run_until_exit_code "${cmd}" "util::test::internal::failure_func" "${duration}" "${interval}"
}
readonly -f util::test::try_until_failure

# util::test::try_until_text runs the cmd until either the command outputs the desired text or times out
# the default time-out for util::test::try_until_text is 60 seconds.
function util::test::try_until_text() {
	if [[ $# -lt 2 ]]; then echo "util::test::try_until_text expects at least two arguments, got $#"; return 1; fi
	local cmd=$1
	local text=$2
	local duration=${3:-$minute}
	local interval=${4:-0.2}

	util::test::internal::run_until_text "${cmd}" "${text}" "util::test::internal::success_func" "${duration}" "${interval}"
}
readonly -f util::test::try_until_text

# util::test::try_until_not_text runs the cmd until either the command doesnot output the text or times out
# the default time-out for util::test::try_until_not_text is 60 seconds.
function util::test::try_until_not_text() {
	if [[ $# -lt 2 ]]; then echo "util::test::try_until_not_text expects at least two arguments, got $#"; return 1; fi
	local cmd=$1
	local text=$2
	local duration=${3:-$minute}
	local interval=${4:-0.2}

	util::test::internal::run_until_text "${cmd}" "${text}" "util::test::internal::failure_func" "${duration}" "${interval}"
}
readonly -f util::test::try_until_text

# util::test::internal::assemble_causes determines from the two input booleans which part of the test
# failed and generates a nice delimited list of failure causes
function util::test::internal::assemble_causes() {
	local cmd_succeeded=$1
	local test_succeeded=$2

	local causes=()
	if (( ! cmd_succeeded )); then
		causes+=("the command returned the wrong error code")
	fi
	if (( ! test_succeeded )); then
		causes+=("the output content test failed")
	fi

	local list=$(printf '; %s' "${causes[@]}")
	echo "${list:2}"
}
readonly -f util::test::internal::assemble_causes

# util::text::reset resets the terminal output to default if it is called in a TTY
function util::text::reset() {
	if util::text::internal::is_tty; then
		tput sgr0
	fi
}
readonly -f util::text::reset

# util::text::bold sets the terminal output to bold text if it is called in a TTY
function util::text::bold() {
	if util::text::internal::is_tty; then
		tput bold
	fi
}
readonly -f util::text::bold

# util::text::red sets the terminal output to red text if it is called in a TTY
function util::text::red() {
	if util::text::internal::is_tty; then
		tput setaf 1
	fi
}
readonly -f util::text::red

# os::text::green sets the terminal output to green text if it is called in a TTY
function util::text::green() {
	if util::text::internal::is_tty; then
		tput setaf 2
	fi
}
readonly -f util::text::green

# os::text::blue sets the terminal output to blue text if it is called in a TTY
function util::text::blue() {
	if util::text::internal::is_tty; then
		tput setaf 4
	fi
}
readonly -f util::text::blue

# util::text::yellow sets the terminal output to yellow text if it is called in a TTY
function util::text::yellow() {
	if util::text::internal::is_tty; then
		tput setaf 11
	fi
}
readonly -f util::text::yellow

# util::text::clear_last_line clears the text from the last line of output to the
# terminal and leaves the cursor on that line to allow for overwriting that text
# if it is called in a TTY
function util::text::clear_last_line() {
	if util::text::internal::is_tty; then
		tput cuu 1
		tput el
	fi
}
readonly -f util::text::clear_last_line

# util::text::clear_string attempts to clear the entirety of a string from the terminal.
# If the string contains literal tabs or other characters that take up more than one
# character space in output, or if the window size is changed before this function
# is called, it will not function correctly.
# No action is taken if this is called outside of a TTY
function util::text::clear_string() {
    local -r string="$1"
    if util::text::internal::is_tty; then
        echo "${string}" | while read line; do
            # num_lines is the number of terminal lines this one line of output
            # would have taken up with the current terminal width in columns
            local num_lines=$(( ${#line} / $( tput cols ) ))
            for (( i = 0; i <= num_lines; i++ )); do
                util::text::clear_last_line
            done
        done
    fi
}

# util::text::internal::is_tty determines if we are outputting to a TTY
function util::text::internal::is_tty() {
	[[ -t 1 && -n "${TERM:-}" ]]
}
readonly -f util::text::internal::is_tty

# util::text::print_bold prints all input in bold text
function util::text::print_bold() {
	util::text::bold
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_bold

# util::text::print_red prints all input in red text
function util::text::print_red() {
	util::text::red
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_red

# util::text::print_red_bold prints all input in bold red text
function util::text::print_red_bold() {
	util::text::red
	util::text::bold
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_red_bold

# util::text::print_green prints all input in green text
function util::text::print_green() {
	util::text::green
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_green

# util::text::print_green_bold prints all input in bold green text
function util::text::print_green_bold() {
	util::text::green
	util::text::bold
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_green_bold

# util::text::print_blue prints all input in blue text
function util::text::print_blue() {
	util::text::blue
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_blue

# util::text::print_blue_bold prints all input in bold blue text
function util::text::print_blue_bold() {
	util::text::blue
	util::text::bold
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_blue_bold

# util::text::print_yellow prints all input in yellow text
function util::text::print_yellow() {
	util::text::yellow
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_yellow

# util::text::print_yellow_bold prints all input in bold yellow text
function util::text::print_yellow_bold() {
	util::text::yellow
	util::text::bold
	echo "${*}"
	util::text::reset
}
readonly -f util::text::print_yellow_bold

# util::test::internal::get_last_results prints the stderr and stdout from the last attempt
function util::test::internal::get_last_results() {
	cat "${os_cmd_internal_tmpout}" | awk 'BEGIN { RS = "\x1e" } END { print $0 }'
	cat "${os_cmd_internal_tmperr}" | awk 'BEGIN { RS = "\x1e" } END { print $0 }'
}
readonly -f util::test::internal::get_last_results

# util::test::internal::mark_attempt marks the end of an attempt in the stdout and stderr log files
# this is used to make the try_until_* output more concise
function util::test::internal::mark_attempt() {
	echo -e '\x1e' >> "${os_cmd_internal_tmpout}"
	echo -e '\x1e' >> "${os_cmd_internal_tmperr}"
}
readonly -f util::test::internal::mark_attempt

# util::test::internal::run_until_exit_code runs the provided command until the exit code test given
# succeeds or the timeout given runs out. Output from the command to be tested is suppressed unless
# either `VERBOSE=1` or the test fails. This function bypasses any error exiting settings or traps
# set by upstream callers by masking the return code of the command with the return code of setting
# the result variable on failure.
#
# Globals:
#  - JUNIT_REPORT_OUTPUT
#  - VERBOSE
# Arguments:
#  - 1: the command to run
#  - 2: command evaluation assertion to use
#  - 3: timeout duration
#  - 4: interval duration
# Returns:
#  - 0: if all assertions met before timeout
#  - 1: if timeout occurs
function util::test::internal::run_until_exit_code() {
	local cmd=$1
	local cmd_eval_func=$2
	local duration=$3
	local interval=$4

	local -a junit_log

	util::test::internal::init_tempdir
	# junit::test::junit::declare_test_start

	local description=$(util::test::internal::describe_call "${cmd}" "${cmd_eval_func}")
	local duration_seconds=$(echo "scale=3; $(( duration )) / 1000" | bc | xargs printf '%5.3f')
	local description="${description}; re-trying every ${interval}s until completion or ${duration_seconds}s"
	local preamble="Running ${description}..."
	echo "${preamble}"
	# for ease of parsing, we want the entire declaration on one line, so we replace '\n' with ';'
	junit_log+=( "${description//$'\n'/;}" )

	local start_time=$(util::test::internal::seconds_since_epoch)

	local deadline=$(( $(date +%s000) + $duration ))
	local cmd_succeeded=0
	while [ $(date +%s000) -lt $deadline ]; do
		local cmd_result=$( util::test::internal::run_collecting_output "${cmd}"; echo $? )
		cmd_succeeded=$( ${cmd_eval_func} "${cmd_result}"; echo $? )
		if (( cmd_succeeded )); then
			break
		fi
		sleep "${interval}"
		util::test::internal::mark_attempt
	done

	local end_time=$(util::test::internal::seconds_since_epoch)
	local time_elapsed=$(echo "scale=9; ${end_time} - ${start_time}" | bc | xargs printf '%5.3f') # in decimal seconds, we need leading zeroes for parsing later

	# clear the preamble so we can print out the success or error message
	util::text::clear_string "${preamble}"

	local return_code
	if (( cmd_succeeded )); then
		util::text::print_green "SUCCESS after ${time_elapsed}s: ${description}"
		junit_log+=( "SUCCESS after ${time_elapsed}s: ${description//$'\n'/;}" )

		if [[ -n ${VERBOSE-} ]]; then
			util::test::internal::print_results
		fi
		return_code=0
	else
		util::text::print_red_bold "FAILURE after ${time_elapsed}s: ${description}: the command timed out"
		junit_log+=( "FAILURE after ${time_elapsed}s: ${description//$'\n'/;}: the command timed out" )

		util::text::print_red "$(util::test::internal::print_results)"
		return_code=1
	fi

	junit_log+=( "$(util::test::internal::print_results)" )
	( IFS=$'\n'; echo "${junit_log[*]}" >> "${JUNIT_REPORT_OUTPUT:-/dev/null}" )
	# junit::test::junit::declare_test_end
	return "${return_code}"
}
readonly -f util::test::internal::run_until_exit_code

# util::test::internal::run_until_text runs the provided command until the assertion function succeeds with
# the given text on the command output or the timeout given runs out. This can be used to run until the
# output does or does not contain some text. Output from the command to be tested is suppressed unless
# either `VERBOSE=1` or the test fails. This function bypasses any error exiting settings or traps
# set by upstream callers by masking the return code of the command with the return code of setting
# the result variable on failure.
#
# Globals:
#  - JUNIT_REPORT_OUTPUT
#  - VERBOSE
# Arguments:
#  - 1: the command to run
#  - 2: text to test for
#  - 3: text assertion to use
#  - 4: timeout duration
#  - 5: interval duration
# Returns:
#  - 0: if all assertions met before timeout
#  - 1: if timeout occurs
function util::test::internal::run_until_text() {
	local cmd=$1
	local text=$2
	local test_eval_func=${3:-util::test::internal::success_func}
	local duration=$4
	local interval=$5

	local -a junit_log

	util::test::internal::init_tempdir
	# junit::test::junit::declare_test_start

	local description=$(util::test::internal::describe_call "${cmd}" "" "${text}" "${test_eval_func}")
	local duration_seconds=$(echo "scale=3; $(( duration )) / 1000" | bc | xargs printf '%5.3f')
	local description="${description}; re-trying every ${interval}s until completion or ${duration_seconds}s"
	local preamble="Running ${description}..."
	echo "${preamble}"
	# for ease of parsing, we want the entire declaration on one line, so we replace '\n' with ';'
	junit_log+=( "${description//$'\n'/;}" )

	local start_time=$(util::test::internal::seconds_since_epoch)

	local deadline=$(( $(date +%s000) + $duration ))
	local test_succeeded=0
	while [ $(date +%s000) -lt $deadline ]; do
		local cmd_result=$( util::test::internal::run_collecting_output "${cmd}"; echo $? )
		local test_result
		test_result=$( util::test::internal::run_collecting_output 'grep -Eq "${text}" <(util::test::internal::get_last_results)'; echo $? )
		test_succeeded=$( ${test_eval_func} "${test_result}"; echo $? )

		if (( test_succeeded )); then
			break
		fi
		sleep "${interval}"
		util::test::internal::mark_attempt
	done

	local end_time=$(util::test::internal::seconds_since_epoch)
	local time_elapsed=$(echo "scale=9; ${end_time} - ${start_time}" | bc | xargs printf '%5.3f') # in decimal seconds, we need leading zeroes for parsing later

  # clear the preamble so we can print out the success or error message
  util::text::clear_string "${preamble}"

	local return_code
	if (( test_succeeded )); then
		util::text::print_green "SUCCESS after ${time_elapsed}s: ${description}"
		junit_log+=( "SUCCESS after ${time_elapsed}s: ${description//$'\n'/;}" )

		if [[ -n ${VERBOSE-} ]]; then
			util::test::internal::print_results
		fi
		return_code=0
	else
		util::text::print_red_bold "FAILURE after ${time_elapsed}s: ${description}: the command timed out"
		junit_log+=( "FAILURE after ${time_elapsed}s: ${description//$'\n'/;}: the command timed out" )

		util::text::print_red "$(util::test::internal::print_results)"
		return_code=1
	fi

	junit_log+=( "$(util::test::internal::print_results)" )
	( IFS=$'\n'; echo "${junit_log[*]}" >> "${JUNIT_REPORT_OUTPUT:-/dev/null}" )
	# junit::test::junit::declare_test_end
	return "${return_code}"
}
readonly -f util::test::internal::run_until_text

function exit_trap() {
    local return_code=$?

    end_time=$(date +%s)

    if [[ "${return_code}" -eq "0" ]]; then
        verb="succeeded"
    else
        verb="failed"
    fi

    echo "$0 ${verb} after $((${end_time} - ${start_time})) seconds"
    exit "${return_code}"
}

#trap exit_trap EXIT
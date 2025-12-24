#!/bin/ash
CLI="ba-cli -l "
CLI_JSON="ba-cli -j -l"

# Performs pkill for the given process name
kill_process() {
        pkill -P 1 -f "$1"
}

# Retrieves the process ID for given process name
get_pid() {
        echo "$1 "$(pgrep -P 1 -f "$1")
}

# Verifies NumProcessRespawn against provided value
verify_process_fail_update() {
        respawn=$(${CLI} "ProcessMonitor.Test.$1.NumProcessRespawn?" | sed '/^$/d')
        process_name=$(${CLI} "ProcessMonitor.Test.$1.Name?" | sed '/^$/d')
        if [ $respawn -eq $2 ]; then
                echo "$process_name NumProcessRespawn PASS"
        else
                echo "FAIL $process_name, expected ProcessMonitor.Test.$1.NumProcessRespawn value: $2 found: $respawn"
        fi
        MaxNumFailed=$(${CLI} "ProcessMonitor.Test.$1.MaxNumFailed?" | sed '/^$/d')
        if [ $MaxNumFailed -eq 0 ]; then
                echo "FAIL $process_name, Expected ProcessMonitor.Test.$1.MaxNumFailed to be updated but found $MaxNumFailed"
        else
                echo "$process_name MaxNumFailed PASS"
        fi
}

# Verifies ProcessMonitoringEnabled is enabled, LastFailReason cleared
# MaxNumFailed, NumProcessFail and NumProcessRespawn are cleared
verify_value_reset() {
        ProcessMonitoringEnabled=$(${CLI} "ProcessMonitor.Test.$1.ProcessMonitoringEnabled?" | sed '/^$/d')
        process_name=$(${CLI} "ProcessMonitor.Test.$1.Name?" | sed '/^$/d')
        if [ $ProcessMonitoringEnabled -eq 1 ]; then
                echo "$process_name ProcessMonitoringEnabled PASS"
        else
                echo "FAIL $process_name, ProcessMonitor.Test.$1.ProcessMonitoringEnabled - $ProcessMonitoringEnabled " \
                "not enabled after reset"
        fi

        MaxNumFailed=$(${CLI} "ProcessMonitor.Test.$1.MaxNumFailed?" | sed '/^$/d')
        if [ $MaxNumFailed -eq 0 ]; then
                echo "$process_name MaxNumFailed PASS"
        else
                echo "FAIL $process_name, ProcessMonitor.Test.$1.MaxNumFailed - $MaxNumFailed not reset"
        fi

        NumProcessFail=$(${CLI} "ProcessMonitor.Test.$1.NumProcessFail?" | sed '/^$/d')
        if [ $NumProcessFail -eq 0 ]; then
                echo "$process_name NumProcessFail PASS"
        else
                echo "FAIL $process_name, ProcessMonitor.Test.$1.NumProcessFail - $NumProcessFail not reset"
        fi

        NumProcessRespawn=$(${CLI} "ProcessMonitor.Test.$1.NumProcessRespawn?" | sed '/^$/d')
        if [ $NumProcessRespawn -eq 0 ]; then
                echo "$process_name NumProcessRespawn PASS"
        else
                echo "FAIL $process_name, ProcessMonitor.Test.$1.NumProcessRespawn - $NumProcessRespawn not reset"
        fi
}

# Calls reset method for given ProcessMonitor.Test.Id
reset_amx_process_monitoring() {
        reset_output=$(${CLI_JSON} "ProcessMonitor.Test.$1.reset()" | sed '/^$/d' | tail -n 1)
        process_name=$(${CLI} "ProcessMonitor.Test.$1.Name?" | sed '/^$/d')
        if [ "[\"\"]" == $reset_output ]; then
                echo "$process_name reset OK"
        else
                echo "$process_name reset Failed"
        fi
}

# Changes monitor type to Process and changes subject to /var/run/<pid> for the given ProcessMonitor.Test.Id
change_process_subject() {
        change_monitor_type=$(${CLI} "ProcessMonitor.Test.$1.Type=Process" | sed '/^$/d')
        change_monitor_subject=$(${CLI} "ProcessMonitor.Test.$1.Subject=$2" | sed '/^$/d')
        change_process_name=$(${CLI} "ProcessMonitor.Test.$1.Name?" | sed '/^$/d')
        if [ "Process" == "$change_monitor_type" ] && [ "$change_monitor_subject" == $2 ]; then
                echo "$change_process_name subject change OK"
        else
                echo "$change_process_name subject change Failed Type: $change_monitor_type Subject: $change_monitor_subject"
        fi
}

# Revert Monitor type to Plugin type and set the Object name to Subject
revert_process_subject() {
        change_monitor_type=$(${CLI} "ProcessMonitor.Test.$1.Type=Plugin" | sed '/^$/d')
        change_monitor_subject=$(${CLI} "ProcessMonitor.Test.$1.Subject=$2" | sed '/^$/d')
        change_process_name=$(${CLI} "ProcessMonitor.Test.$1.Name?" | sed '/^$/d')
        if [ "Plugin" == "$change_monitor_type" ] && [ "$change_monitor_subject" == $2 ]; then
                echo "$change_process_name subject revert OK"
        else
                echo "$change_process_name subject revert Failed Type: $change_monitor_type Subject: $change_monitor_subject"
        fi
}

# Verify NumProcessRespawn against given value
verify_respawn_value() {
        respawn=$(${CLI} "ProcessMonitor.Test.$1.NumProcessRespawn?" | sed '/^$/d')
        process_name=$(${CLI} "ProcessMonitor.Test.$1.Name?" | sed '/^$/d')
        if [ $respawn -eq $2 ]; then
                echo "$process_name NumProcessRespawn PASS"
        else
                echo "FAIL $process_name, expected ProcessMonitor.Test.$1.NumProcessRespawn value: $2 found: $respawn"
        fi
}

# Verifies NumProcessFail against expected value
verify_num_Process_fail() {
        num_process_fail=$(${CLI} "ProcessMonitor.Test.$1.NumProcessFail?" | sed '/^$/d')
        process_name=$(${CLI} "ProcessMonitor.Test.$1.Name?" | sed '/^$/d')
        if [ $num_process_fail -eq $2 ]; then
                echo "$process_name NumProcessFail PASS"
        else
                echo "Fail $process_name, Expected value for ProcessMonitor.Test.$1.NumProcessFail: $2, found: $num_process_fail"
        fi
}

# Gets TestInterval for provided ProcessMonitor.Test.i
get_test_interval() {
        ${CLI} "ProcessMonitor.Test.$1.TestInterval?" > /dev/null
}

# Sets TestInterval for provided ProcessMonitor.Test.i to shorter interval
# Parameter #1 - Value i of ProcessMonitor.Test.i
# Parameter #2 - TestInterval value
set_test_interval() {
	set -- "$@"
	test_interval=$1
	shift
	for test in "$@"; do
		${CLI} "ProcessMonitor.Test.$test.TestInterval=$test_interval" > /dev/null
	done
}

# Retrieves CurrentTestInterval and Health for provided ProcessMonitor.Test.i
# Parameter #1 - values of ProcessMonitor.Test.i for all of which Health and
# CurrentTestInterval is retruned
get_health_and_interval() {
        for test in "$@"; do
                name=$(${CLI} "ProcessMonitor.Test.$test.Name?")
                current_test_interval=$(${CLI} "ProcessMonitor.Test.$test.CurrentTestInterval?")
                health=$(${CLI} "ProcessMonitor.Test.$test.Health?")
                echo $name $current_test_interval $health
        done
}


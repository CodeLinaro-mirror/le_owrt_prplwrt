#!/bin/bash

log_error() { echo -e "\e[91m❌ ERROR: $*\e[0m"; }
log_success() { echo -e "\e[92m✅ $*\e[0m"; }
log_info() { echo -e "\e[93m💡 $*\e[0m"; }

# section_start - Start a collapsible section in GitLab CI job logs
#
# Creates a collapsible section marker in GitLab CI logs that can be expanded
# or collapsed in the web interface.
#
# Parameters:
#   $1 - section_title: Unique identifier for the section (required)
#   $2 - section_description: Display name shown in the UI (optional, defaults to section_title)
#   $3 - collapse_state: "collapsed" or "expanded" (optional, defaults to "expanded")
#
# Usage:
#   section_start "build_logs" "Build Output"
#   section_start "test_results" "Test Results" "collapsed"
#   section_start "warnings"
#
# Note: Each section_start must have a matching section_end with the same section_title
#
section_start() {
	local section_title="${1}"
	local section_description="${2:-$section_title}"
	local collapse_state="${3:-expanded}"
	local collapsed_flag="false"

	if [ "$collapse_state" = "collapsed" ]; then
		collapsed_flag="true"
	fi

	echo -e "section_start:$(date +%s):${section_title}[collapsed=${collapsed_flag}]\r\e[0K\e[95m📦 ${section_description}\e[0m"
}

# section_end - End a collapsible section in GitLab CI job logs
#
# Closes a section that was opened with section_start. The section_title must
# match the one used in the corresponding section_start call.
#
# Parameters:
#   $1 - section_title: Unique identifier for the section (required, must match section_start)
#
# Usage:
#   section_end "build_logs"
#   section_end "test_results"
#
# Example workflow:
#   section_start "build_logs" "Build Output"
#   make build
#   section_end "build_logs"
#
section_end() {
	local section_title="${1}"

	echo -e "section_end:$(date +%s):${section_title}\r\e[0K"
}

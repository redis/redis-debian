#!/bin/bash

# Sources a helper file from multiple possible locations (GITHUB_WORKSPACE, RELEASE_AUTOMATION_DIR, or relative path)
source_helper_file() {
    local helper_file="$1"
    local helper_errors=""
    for dir in "GITHUB_WORKSPACE:$GITHUB_WORKSPACE/redis-oss-release-automation" "RELEASE_AUTOMATION_DIR:$RELEASE_AUTOMATION_DIR" ":../redis-oss-release-automation"; do
        local var_name="${dir%%:*}"
        local dir="${dir#*:}"
        if [ -n "$var_name" ]; then
            var_name="\$$var_name"
        fi
        local helper_path="$dir/.github/actions/common/$helper_file"
        if [ -f "$helper_path" ]; then
            helper_errors=""
            # shellcheck disable=SC1090
            . "$helper_path"
            break
        else
            helper_errors=$(printf "%s\n  %s: %s" "$helper_errors" "$var_name" "$helper_path")
        fi
    done
    if [ -n "$helper_errors" ]; then
        echo "Error: $helper_file not found in any of the following locations: $helper_errors" >&2
        exit 1
    fi
}
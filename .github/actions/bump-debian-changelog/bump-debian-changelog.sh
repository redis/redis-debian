#!/bin/bash
set -e

# This script updates debian/changelog using the provided TAG
# and commits changes if any were made.

# shellcheck disable=SC2034
last_cmd_stdout=""
# shellcheck disable=SC2034
last_cmd_stderr=""
# shellcheck disable=SC2034
last_cmd_result=0
# shellcheck disable=SC2034
VERBOSITY=1



SCRIPT_DIR="$(dirname -- "$( readlink -f -- "$0"; )")"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../common/func.sh"

source_helper_file helpers.sh

# Input TAG is expected in $1
TAG="$1"

if [ -z "$TAG" ]; then
    echo "Error: TAG is required as first argument"
    exit 1
fi

echo "TAG: $TAG"

# Function to update changelog
update_debian_changelog() {
    local changelog="$1"
    local tag="$2"

    if [ ! -f "$changelog" ]; then
        echo "Warning: $changelog not found, skipping"
        return 1
    fi

    echo "Updating $changelog..."

    # Check if this version already exists in changelog
    if grep -q "^redis (.*:$tag-" "$changelog"; then
        echo "Version $tag already exists in $changelog, skipping"
        return 1
    fi

    # Get author from the most recent entry
    AUTHOR=$(grep -m 1 '^ --' "$changelog" | sed 's/^ -- \(.*>\)  *.*$/\1/')

    if [ -z "$AUTHOR" ]; then
        echo "Error: Could not determine author from $changelog"
        return 1
    fi

    # Create temporary file with new entry
    temp_changelog=$(mktemp)

    # Add new entry at the top
    cat > "$temp_changelog" << EOF
redis (6:$tag-1rl1~@RELEASE@1) @RELEASE@; urgency=low

  * Redis $tag: https://github.com/redis/redis/releases/tag/$tag

 -- $AUTHOR  $(date -R)

EOF

    # Append existing changelog
    cat "$changelog" >> "$temp_changelog"

    # Replace original with updated version
    mv "$temp_changelog" "$changelog"

    echo "Successfully updated $changelog with version $tag"
    return 0
}

changelog_file="debian/changelog"
# Track which files were modified
changed_files=()

# Update the changelog
if update_debian_changelog "$changelog_file" "$TAG"; then
    changed_files+=("$changelog_file")
fi

# Check what files actually changed in git
mapfile -t changed_files < <(git diff --name-only "$changelog_file")

# Output the list of changed files for GitHub Actions
if [ ${#changed_files[@]} -gt 0 ]; then
    echo "Files were modified:"
    printf '%s\n' "${changed_files[@]}"

    if [ -z "$GITHUB_OUTPUT" ]; then
        GITHUB_OUTPUT=/dev/stdout
    fi

    # Set GitHub Actions output
    changed_files_output=$(printf '%s\n' "${changed_files[@]}")
    {
        echo "changed_files<<EOF"
        echo "$changed_files_output"
        echo "EOF"
    } >> "$GITHUB_OUTPUT"

    echo "Changed files output set for next step"
else
    echo "No files were modified"
    echo "changed_files=" >> "$GITHUB_OUTPUT"
fi
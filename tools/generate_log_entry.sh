#!/bin/bash

# This script generates a new log entry for SHARED_WORKSPACE.md with a system-generated timestamp.

# Determine project root relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AGENT_NAME="$1"
ACTION="$2"
FILES_MODIFIED="$3"
MESSAGE="$4"

# Get the current timestamp using a system command
TIMESTAMP=$(date "+%Y-%m-%d %H:%M %Z")

# Format the log entry
LOG_ENTRY="\n### $TIMESTAMP - $AGENT_NAME\n**Action**: $ACTION\n**Files Modified**: $FILES_MODIFIED\n**Message for User**: $MESSAGE\n"

# Append the log entry to SHARED_WORKSPACE.md using project-relative path
echo -e "$LOG_ENTRY" >> "$PROJECT_ROOT/team/SHARED_WORKSPACE.md"


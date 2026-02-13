#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

# Check if correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <GIT_RANGE>"
    echo
    echo "To check just  HAED commit do:"
    echo "    $0 HEAD^..HEAD"
    exit 1
fi

SELF="$(dirname "${BASH_SOURCE[0]}")"

COMMITS=()
mapfile -t COMMITS < <(git rev-list --no-merges "$1")

"${SELF}/histo.sh" "${COMMITS[@]}"

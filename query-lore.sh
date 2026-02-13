#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

# Validate input
if [ $# -ne 1 ]; then
    echo "Usage: $0 <commit-id>" >&2
    exit 1
fi

commit_id="$1"

# Validate commit ID format
if ! [[ $commit_id =~ ^[0-9a-f]{40}$ ]] && ! [[ $commit_id =~ ^[0-9a-f]{12,39}$ ]]; then
    echo "Error: Invalid commit ID format" >&2
    exit 1
fi

# Get commit details
if ! git rev-parse --quiet --verify "$commit_id^{commit}" >/dev/null; then
    echo "Error: Commit not found in current repository" >&2
    exit 1
fi

# Get commit subject and patch ID
subject=$(git log -1 --format=%s "$commit_id")
patch_id=$(git show "$commit_id" | git patch-id --stable | cut -d' ' -f1)

# Function to URL encode strings
urlencode() {
    jq -sRr @uri <<<"$1"
}

# Function to perform search and extract message IDs from href fields
search_and_get_msgids() {
    local query="$1"
    local encoded_query=$(urlencode "$query")
    curl -s "https://lore.kernel.org/all/?q=$encoded_query" |
        grep -o 'href="[^"]*"' |
        sed 's/href="//' |
        sed 's/"//' |
        grep '^[[:alnum:]]' |
        sed 's|^|https://lore.kernel.org/all/|'
}

# Perform all searches and combine results
{
    # Search by commit ID in body
    search_and_get_msgids "b:\"$commit_id\""
    
    # Search by commit ID in diff blobs
    search_and_get_msgids "dfblob:\"$commit_id\""
    
    # Search by subject (exact phrase)
    search_and_get_msgids "s:\"$subject\""
    
    # Search by patch ID
    search_and_get_msgids "patchid:$patch_id"
} | sort -u

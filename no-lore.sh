#!/bin/bash

# Check if we have at least 2 arguments (db path and at least one commit)
if [ $# -lt 2 ]; then
    echo "Usage: $0 <database_path> <commit_id1> [commit_id2 ...]"
    exit 1
fi

# Store the database path and remove it from arguments
DB_PATH="$1"
shift

# Check if database path exists
if [ ! -d "$DB_PATH" ]; then
    echo "Error: Database directory '$DB_PATH' does not exist"
    exit 1
fi

# Check if query-lore.sh is available in PATH
if ! command -v query-lore.sh &> /dev/null; then
    echo "Error: query-lore.sh not found in PATH"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get total number of commits being processed
total_commits=$#

# Process each commit ID and store commits without URLs
commits_without_urls=()
for commit in "$@"; do
    # Run query-lore.sh and count the number of URLs returned
    url_count=$(query-lore.sh "$commit" | wc -l)
    
    # If no URLs were returned (count is 0), store the commit ID
    if [ "$url_count" -eq 0 ]; then
        commits_without_urls+=("$commit")
    fi
done

# If we found any commits without URLs, print header and commits
if [ ${#commits_without_urls[@]} -gt 0 ]; then
    # Calculate percentage
    percentage=$(awk "BEGIN {printf \"%.0f\", (${#commits_without_urls[@]} / $total_commits) * 100}")
    
    # Print header with statistics
    echo "Commits not found on lore.kernel.org/all (${#commits_without_urls[@]} of $total_commits: ${percentage}%)"
    echo "----------------------------------------"

    # Convert array to space-separated string
    commit_list="${commits_without_urls[*]}"
    # Use git log to print the commits in oneline format
    git log --oneline --no-walk --stat $commit_list
else
    echo "I found all commits on various lore.kernel.org mailing lists."
fi

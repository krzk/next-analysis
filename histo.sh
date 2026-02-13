#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <commit-id1> [commit-id2 ...]"
    exit 1
fi

SELF="$(dirname "${BASH_SOURCE[0]}")"
# Get database path from first argument
DB_PATH="${SELF}/db"

# Initialize array for counting numbers 0-14+
# Using -1 index for <1 day category
declare -A counts
counts[-1]=0  # <1 day category
for i in {0..14}; do
    counts[$i]=0
done

# Initialize array to store commits with value 0
declare -a zero_commits

# Keep track of total commits
total_commits=0

# Helper function to convert next-YYYYMMDD to unix timestamp
get_timestamp() {
    local tag=$1
    # Extract YYYYMMDD part from next-YYYYMMDD format
    local date_str=${tag#next-}
    # Convert to timestamp using date command
    date -d "${date_str:0:4}-${date_str:4:2}-${date_str:6:2}" +%s
}

# Get today's timestamp
today_ts=$(date +%s)

# Process each commit ID
for commit in "$@"; do
    # Get result string from query-db.sh
    tags_str=$("${SELF}/query-db.sh" "$DB_PATH" "$commit")
    
    # If there are no tags, count as 0 days (not found)
    if [ -z "$tags_str" ]; then
        ((counts[0]++))
        ((total_commits++))
        zero_commits+=("$commit")
        continue
    fi

    # Split tags into array and sort them
    IFS=$'\n' read -d '' -r -a tags < <(echo "$tags_str" | tr ' ' '\n' | sort)

    if [ ${#tags[@]} -eq 0 ]; then
        ((counts[0]++))
        ((total_commits++))
        zero_commits+=("$commit")
        continue
    fi

    # Get first timestamp
    first_ts=$(get_timestamp "${tags[0]}")
    
    # For last timestamp: if commit is in the newest tag, use today's date
    newest_tag=$(echo "$tags_str" | tr ' ' '\n' | sort | tail -n 1)
    newest_tag_ts=$(get_timestamp "$newest_tag")
    
    # Check if this tag is the most recent chronologically
    all_tags=$("${SELF}/query-db.sh" "$DB_PATH" "list-tags")
    most_recent_tag=$(echo "$all_tags" | tr ' ' '\n' | sort | tail -n 1)
    most_recent_ts=$(get_timestamp "$most_recent_tag")
    
    if [ "$newest_tag_ts" -eq "$most_recent_ts" ]; then
        last_ts=$today_ts
    else
        last_ts=$newest_tag_ts
    fi
    
    # Calculate days difference
    days=$(( (last_ts - first_ts) / 86400 ))

    ((total_commits++))
    
    # If days is 0 and tags were found, count in <1 category
    if [ "$days" -eq 0 ] && [ ! -z "$tags_str" ]; then
        ((counts[-1]++))
        zero_commits+=("$commit")
    # If days is greater than 14, count in the 14+ category
    elif [ "$days" -gt 14 ]; then
        ((counts[14]++))
    else
        ((counts[$days]++))
        # Store commit ID if days is 0 (not found case)
        if [ "$days" -eq 0 ]; then
            zero_commits+=("$commit")
        fi
    fi
done

# Find maximum count for scaling
max_count=0
# Find the last populated row
last_populated=0
for i in {0..14}; do
    if [ "${counts[$i]}" -gt 0 ]; then
        last_populated=$i
        if [ "${counts[$i]}" -gt "$max_count" ]; then
            max_count=${counts[$i]}
        fi
    fi
done
# Check if <1 category should affect max_count
if [ "${counts[-1]}" -gt "$max_count" ]; then
    max_count=${counts[-1]}
fi

# Only apply scaling if max_count exceeds 50
if [ "$max_count" -gt 50 ]; then
    factor=$(bc -l <<< "50/$max_count")
else
    factor=1
fi

# Print histogram header
echo "Days in linux-next:"
echo "----------------------------------------"

# Print 0 row first if it has entries
if [ "${counts[0]}" -gt 0 ]; then
    blocks=$(bc -l <<< "${counts[0]}*$factor" | cut -d. -f1)
    printf " 0 | "
    for ((j=0; j<blocks; j++)); do
        printf "+"
    done
    printf " (%d)\n" "${counts[0]}"
fi

# Print <1 row next if it has entries
if [ "${counts[-1]}" -gt 0 ]; then
    blocks=$(bc -l <<< "${counts[-1]}*$factor" | cut -d. -f1)
    printf "<1 | "
    for ((j=0; j<blocks; j++)); do
        printf "+"
    done
    printf " (%d)\n" "${counts[-1]}"
fi

# Print rest of histogram (starting from 1)
for i in $(seq 1 $last_populated); do
    # Calculate number of blocks to print
    blocks=$(bc -l <<< "${counts[$i]}*$factor" | cut -d. -f1)
    
    # Print line with padding for number alignment and special label for 14+
    if [ "$i" -eq 14 ]; then
        printf "14+| "
    else
        printf "%2d | " "$i"
    fi
    
    # Print blocks
    if [ "$blocks" -gt 0 ]; then
        for ((j=0; j<blocks; j++)); do
            printf "+"
        done
        printf " (%d)\n" "${counts[$i]}"
    else
        echo
    fi
done

# Print commits with value 0 or <1
if [ ${#zero_commits[@]} -gt 0 ]; then
    # Calculate percentage
    percentage=$(bc -l <<< "scale=1; ${#zero_commits[@]}*100/$total_commits")
    
    echo -e "\nCommits with 0 days in linux-next (${#zero_commits[@]} of $total_commits: ${percentage}%):"
    echo "--------------------------------"
    for commit in "${zero_commits[@]}"; do
        git log --oneline --stat -n 1 "$commit"
        echo
    done
fi

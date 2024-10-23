#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <database-path> <commit-id1> [commit-id2 ...]"
    exit 1
fi

# Get database path from first argument
DB_PATH="$1"
shift  # Remove first argument, leaving only commit IDs

# Initialize array for counting numbers 0-14+
declare -A counts
for i in {0..14}; do
    counts[$i]=0
done

# Initialize array to store commits with value 0
declare -a zero_commits

# Keep track of total commits
total_commits=0

# Process each commit ID
for commit in "$@"; do
    # Get result from query-db.sh
    result=$(query-db.sh "$DB_PATH" "$commit")
    
    # Validate result is a number
    if [[ "$result" =~ ^[0-9]+$ ]]; then
        ((total_commits++))
        # If result is greater than 14, count it in the 14+ category
        if [ "$result" -gt 14 ]; then
            ((counts[14]++))
        else
            ((counts[$result]++))
            # Store commit ID if result is 0
            if [ "$result" -eq 0 ]; then
                zero_commits+=("$commit")
            fi
        fi
    else
        echo "Warning: Invalid result '$result' for commit $commit" >&2
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

# Calculate scale factor (max 50 characters wide)
scale=50
if [ "$max_count" -gt 0 ]; then
    factor=$(bc -l <<< "$scale/$max_count")
else
    factor=0
fi

# Print histogram
echo "Days in linux-next:"
echo "----------------------------------------"
for i in $(seq 0 $last_populated); do
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
            printf "█"
        done
        printf " (%d)\n" "${counts[$i]}"
    else
        echo
    fi
done

# Print commits with value 0
if [ ${#zero_commits[@]} -gt 0 ]; then
    # Calculate percentage
    percentage=$(bc -l <<< "scale=1; ${#zero_commits[@]}*100/$total_commits")
    
    echo -e "\nCommits with 0 days in linux-next (${#zero_commits[@]} of $total_commits: ${percentage}%):"
    echo "--------------------------------"
    for commit in "${zero_commits[@]}"; do
        git log --oneline -n 1 "$commit"
    done
fi

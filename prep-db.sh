#!/bin/bash

# Check if directory parameter is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <database-directory>"
    exit 1
fi

DB_DIR="$1"

# Create database directory if it doesn't exist
mkdir -p "$DB_DIR"

# Get all tags matching the pattern "next-YYYYMMDD"
git tag | grep "^next-[0-9]\{8\}" | while read -r tag; do
    output_file="$DB_DIR/$tag"
    
    # Skip if file already exists
    if [ -f "$output_file" ]; then
        echo "Skipping existing file for tag: $tag"
        continue
    fi
    
    # Get all non-merge commits between origin/master and the tag
    git log --no-merges origin/master.."$tag" --format="%H" | while read -r commit; do
        # Get patch ID for the commit with --stable flag
        patch_id=$(git show "$commit" | git patch-id --stable | cut -d' ' -f1)
        
        # Get commit subject and create hash
        subject_hash=$(git log -1 --format="%s" "$commit" | sha256sum | cut -d' ' -f1)
        
        # Write to output file: commit_id patch_id subject_hash
        echo "$commit $patch_id $subject_hash" >> "$output_file"
    done
    
    # Check if any commits were found and written
    if [ ! -s "$output_file" ]; then
        echo "No commits found for tag: $tag"
        rm "$output_file"
    else
        echo "Processed tag: $tag"
    fi
done

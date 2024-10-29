#!/bin/bash

# Check if directory parameter is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <database-directory>"
    exit 1
fi

DB_DIR="$1"

# Create database directory if it doesn't exist
mkdir -p "$DB_DIR"

# Function to extract origin SHA1 from a tag
get_origin_sha1() {
    local tag="$1"
    # Show contents of Next/SHA1s file in the tag and extract origin's SHA1
    git show "$tag:Next/SHA1s" | awk '$1 == "origin" {print $2}'
}

# Get all tags matching the pattern "next-YYYYMMDD"
git tag | grep "^next-[0-9]\{8\}" | while read -r tag; do
    output_file="$DB_DIR/$tag"
    
    # Skip if file already exists
    if [ -f "$output_file" ]; then
        echo "Skipping existing file for tag: $tag"
        continue
    fi
    
    # Get the origin SHA1 from the tag's Next/SHA1s file
    origin_sha1=$(get_origin_sha1 "$tag")
    
    if [ -z "$origin_sha1" ]; then
        echo "Error: Could not find origin SHA1 in tag: $tag"
        continue
    fi
    
    # Get all non-merge commits between origin SHA1 and the tag
    git log --no-merges "$origin_sha1".."$tag" --format="%H" | while read -r commit; do
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

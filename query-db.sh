#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

# Check if correct number of arguments provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <database_directory> <commit_id>"
    exit 1
fi

db_dir="$1"
commit_id="$2"

# Check if directory exists
if [ ! -d "$db_dir" ]; then
    echo "Error: Directory '$db_dir' does not exist"
    exit 1
fi

# Special case: list all files if commit_id is "list-tags"
if [ "$commit_id" = "list-tags" ]; then
    ls "$db_dir"/next-* 2>/dev/null | sed "s#^${db_dir}/##" | sort
    exit 0
fi

# Check if git command exists
if ! command -v git &> /dev/null; then
    echo "Error: git command not found"
    exit 1
fi

# Calculate patch ID
patch_id=$(git show "$commit_id" | git patch-id --stable | cut -d' ' -f1)
if [ $? -ne 0 ]; then
    echo "Error: Failed to calculate patch ID"
    exit 1
fi

# Calculate subject hash
subject_hash=$(git log --format=%s -n 1 "$commit_id" | sha256sum | cut -d' ' -f1)
if [ $? -ne 0 ]; then
    echo "Error: Failed to calculate subject hash"
    exit 1
fi

# Find all matches and print unique filenames without path
{
    grep -l "^${commit_id}" "$db_dir"/next-* 2>/dev/null
    grep -l "^[^\t]*\t${patch_id}" "$db_dir"/next-* 2>/dev/null
    grep -l "^[^\t]*\t[^\t]*\t${subject_hash}" "$db_dir"/next-* 2>/dev/null
} | sed "s#^${db_dir}/##" | sort -u

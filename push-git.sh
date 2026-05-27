#!/bin/bash

# I am lazy to write this every time so automate it.

# Function to handle Ctrl+C (SIGINT)
cleanup() {
    echo -e "\n\n[!] Operation cancelled by user (Ctrl+C)."
    echo "Cleaning up staging area..."
    # 'git reset' unstages all files that were added
    git reset
    echo "Staging area has been cleaned."
    exit 1
}

# Trap SIGINT (Ctrl+C) and call the cleanup function
trap cleanup SIGINT

# 1. Show status
git status

# 2. Ask for confirmation
echo "-----------------------------------"
read -p "Do you want to proceed with add & commit? (y/n) " confirmation

if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
    # 3. Add all files
    git add .
    echo "Files added to staging."

    # 4. Request commit message
    read -p "Enter your commit message: " user_input
    
    # Use default message if input is empty
    if [ -z "$user_input" ]; then
        user_input="Automatic update: $(TZ=UTC date)"
    fi

    # 5. Commit and Push
    git commit -m "$user_input"
    if git push; then
        echo "Success! Changes have been pushed to GitHub."
    else
        echo "Error: Push failed. Please check your SSH key or remote URL."
        exit 1
    fi
    git pull --rebase origin main
else
    echo "Process aborted."
fi

#!/bin/bash

# I am lazy to write this every time so automate it.

# Function to handle errors/cleanup
cleanup() {
    echo -e "\n\n[!] Operation cancelled or failed."
    git reset
    exit 1
}
trap cleanup SIGINT

echo "Stashing local changes..."
git stash push -m "Auto-stash before pull"

# 2. Fetch & Pull
echo "Fetching latest changes from GitHub..."
git pull --rebase origin main

echo "Restoring local changes..."
git stash pop

# 4. Status
git status

# 5. Confirm Add & Commit
echo "-----------------------------------"
read -p "Do you want to proceed with add & commit? (y/n) " confirmation

if [[ $confirmation == "y" || $confirmation == "Y" ]]; then
    git add .
    echo "Files added to staging."

    read -p "Enter your commit message: " user_input
    if [ -z "$user_input" ]; then
        user_input="Automatic: $(date +%Y-%m-%d)"
    fi

    git commit -m "$user_input"
    
    echo "Pushing to GitHub..."
    if git push origin main; then
        echo "Success! Changes have been pushed to GitHub."
        echo "Pulling latest changes from GitHub to stay in sync..."
        sleep 5
        git pull --rebase origin main
    else
        echo "Error: Push failed. Check your SSH/Network."
        exit 1
    fi
else
    echo "Process aborted."
fi

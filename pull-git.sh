#!/bin/bash
# pull-git.sh

echo "Fetching latest changes from GitHub..."
git pull --rebase origin main

echo "Done! Your local repo is now in sync with GitHub."

#!/bin/bash
set -euo pipefail

# Configurable paths
REPO_PARENT="/home/private/repos"                 
REPO_DIR="$REPO_PARENT/wp-backup-update-clean"    
SCRIPT_DEST="/home/private/wp-maintenance.sh"
CONFIG_DEST="/home/private/wp-maintenance.conf"
TMP_BACKUP_DIR="/home/tmp/backups"
FINAL_BACKUP_DIR="/home/private/wordpress-maintenance-backups"

# Function to prompt and create directory
create_dir_if_needed() {
    local dir="$1"
    local description="$2"

    if [[ ! -d "$dir" ]]; then
        echo "$description ($dir) does not exist."
        read -p "Create it now? (Y/n): " answer
        answer=${answer:-Y}
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            mkdir -p "$dir"
            echo "Created $dir"
        else
            echo "Aborting — $dir is required."
            exit 1
        fi
    fi
}

echo "Setting up wp-backup-update-clean..."

# Step 1: Ensure repo parent directory exists
create_dir_if_needed "$REPO_PARENT" "Repository parent directory"

# Step 2: Clone repo if not present
if [[ ! -d "$REPO_DIR" ]]; then
    echo "Repository not found in $REPO_DIR."
    read -p "Clone the repository now? (Y/n): " answer
    answer=${answer:-Y}
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        git clone git@github.com:cbrunning/wp-backup-update-clean.git "$REPO_DIR"
        echo "Cloned to $REPO_DIR"
    else
        echo "Aborting."
        exit 1
    fi
fi

# Step 3: Update repo
cd "$REPO_DIR"
echo "Updating repository..."
git pull origin main
chmod 700 "$REPO_DIR/update-wp-maintenance.sh"  

# Step 4: Install script and config
cp wp-maintenance.sh "$SCRIPT_DEST"
chmod 700 "$SCRIPT_DEST"
echo "Installed script to $SCRIPT_DEST"

# Step 5: Directories
create_dir_if_needed "$TMP_BACKUP_DIR" "Temporary backup directory"
create_dir_if_needed "$FINAL_BACKUP_DIR" "Final backup storage directory"

# Step 6: Config
if [[ ! -f "$CONFIG_DEST" ]]; then
    echo
    echo "No configuration found. Copying NFSN example..."
    cp wp-maintenance.conf.nfsn-example "$CONFIG_DEST"
    echo "-- Created $CONFIG_DEST"
    echo "   Please edit DOMAIN and other settings!"
else
    echo "Existing config preserved at $CONFIG_DEST"
fi

echo
echo "Setup complete!"
echo "Cron command: $SCRIPT_DEST --quiet"
echo "Repository: $REPO_DIR"
echo "Version: $(git rev-parse --short HEAD)"

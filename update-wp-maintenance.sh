#!/bin/bash
set -euo pipefail

# ==================== Configuration ====================
REPO_PARENT="/home/private/repos"
REPO_DIR="$REPO_PARENT/wp-backup-update-clean"
SCRIPT_DEST="/home/private/wp-maintenance.sh"
CONFIG_DEST="/home/private/wp-maintenance.conf"
TMP_BACKUP_DIR="/home/tmp/backups"
FINAL_BACKUP_DIR="/home/private/wordpress-maintenance-backups"

# Flags
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet|--cron)
            QUIET=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--quiet|--cron]" >&2
            exit 1
            ;;
    esac
done

# Function to prompt and create directory (silent in quiet mode)
create_dir_if_needed() {
    local dir="$1"
    local description="$2"

    if [[ ! -d "$dir" ]]; then
        if $QUIET; then
            echo "Aborting — $dir is required." >&2
            exit 1
        fi
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
    if $QUIET; then
        echo "Repository not found. Aborting in quiet mode." >&2
        exit 1
    fi
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
if $QUIET; then
    git pull --quiet origin main || true
else
    echo "Updating repository..."
    git pull origin main
fi

# If we are in quiet mode and nothing changed, exit silently
if $QUIET && git diff --quiet HEAD@{1} HEAD 2>/dev/null; then
    exit 0
fi

# Step 4: Install script and ensure executable
cp wp-maintenance.sh "$SCRIPT_DEST"
chmod 700 "$SCRIPT_DEST"
[[ $QUIET ]] || echo "Installed script to $SCRIPT_DEST"

# Step 5: Directories
create_dir_if_needed "$TMP_BACKUP_DIR" "Temporary backup directory"
create_dir_if_needed "$FINAL_BACKUP_DIR" "Final backup storage directory"

# Step 6: Handle configuration
if [[ ! -f "$CONFIG_DEST" ]]; then
    if $QUIET; then
        cp wp-maintenance.conf.nfsn-example "$CONFIG_DEST"
    else
        echo
        echo "No configuration found. Copying NFSN example..."
        cp wp-maintenance.conf.nfsn-example "$CONFIG_DEST"
        echo "→ Created $CONFIG_DEST"
        echo "   Please edit DOMAIN and other settings!"
    fi
else
    # Only backup if we are going to modify the config
    if ! grep -q "^RETENTION_WPCLI=" "$CONFIG_DEST"; then
        CONFIG_BACKUP="$CONFIG_DEST.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_DEST" "$CONFIG_BACKUP"
        [[ $QUIET ]] || echo "Backed up existing config to $CONFIG_BACKUP"

        # Insert RETENTION_WPCLI after RETENTION_LOGS
        awk '/^RETENTION_LOGS=/ {print; print "RETENTION_WPCLI=90       # days to keep WP-CLI caches (default 90 if not set)"; next} {print}' "$CONFIG_DEST" > "$CONFIG_DEST.tmp"
        mv "$CONFIG_DEST.tmp" "$CONFIG_DEST"
        [[ $QUIET ]] || echo "Inserted RETENTION_WPCLI=90 into $CONFIG_DEST"
    else
        [[ $QUIET ]] || echo "Existing config preserved at $CONFIG_DEST (RETENTION_WPCLI already defined)."
    fi
fi

# Final output only if not in quiet mode
if ! $QUIET; then
    echo
    echo "Setup complete!"
    echo "Main script: $SCRIPT_DEST"
    echo "Current version: $(git rev-parse --short HEAD)"
    echo
    echo "You can now run the maintenance script with:"
    echo "  $SCRIPT_DEST"
    echo "  or with a custom config: /path/to/wp-maintenance.sh -c /path/to/custom.conf"
    echo
    echo "Run a dry test with:"
    echo "  $SCRIPT_DEST --dry-run"
fi

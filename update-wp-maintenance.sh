#!/bin/bash 
set -euo pipefail 

# ==================== Configuration ====================
HOME_DIR="${HOME%/}"

INSTALL_BASE="${INSTALL_BASE:-$HOME_DIR/wp-maintenance}"
INSTALL_BASE="${INSTALL_BASE%/}"

REPO_PARENT="${REPO_PARENT:-$INSTALL_BASE/repos}"
REPO_DIR="${REPO_DIR:-$REPO_PARENT/wp-backup-update-clean}"
SCRIPT_DEST="${SCRIPT_DEST:-$INSTALL_BASE/wp-maintenance.sh}"
SCRIPT_BASE_DIR="${SCRIPT_BASE_DIR:-$INSTALL_BASE}"

GENERIC_EXAMPLE="${GENERIC_EXAMPLE:-$REPO_DIR/wp-maintenance-generic.conf.example}"
NFSN_EXAMPLE="${NFSN_EXAMPLE:-$REPO_DIR/wp-maintenance-nfsn.conf.example}"

if [[ "$HOME_DIR" == "/home/private" ]]; then
    TMP_BACKUP_DIR_DEFAULT="/home/tmp/backups"
else
    TMP_BACKUP_DIR_DEFAULT="$HOME_DIR/tmp/backups"
fi

TMP_BACKUP_DIR="${TMP_BACKUP_DIR:-$TMP_BACKUP_DIR_DEFAULT}"
FINAL_BACKUP_DIR="${FINAL_BACKUP_DIR:-$SCRIPT_BASE_DIR/wordpress-maintenance-backups}"

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

say() {
    $QUIET && return 0
    echo "$@"
}

abort() {
    echo "$@" >&2
    exit 1
}

# Function to prompt and create directory (silent in quiet mode)
create_dir_if_needed() {
    local dir="$1"
    local description="$2"

    if [[ ! -d "$dir" ]]; then
        if $QUIET; then
            echo "Aborting - $dir is required." >&2
            exit 1
        fi
        echo "$description ($dir) does not exist."
        read -p "Create it now? (Y/n): " answer
        answer=${answer:-Y}
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            mkdir -p "$dir"
            echo "Created $dir"
        else
            echo "Aborting - $dir is required."
            exit 1
        fi
    fi
}

say "Setting up wp-backup-update-clean..."

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
$QUIET || echo "Installed script to $SCRIPT_DEST"

# Step 5: Directories
create_dir_if_needed "$TMP_BACKUP_DIR" "Temporary backup directory"
create_dir_if_needed "$FINAL_BACKUP_DIR" "Final backup storage directory"

# Config discovery

find_conf_files() {
    find "$SCRIPT_BASE_DIR" -maxdepth 1 -type f -name 'wp-maintenance*.conf' | sort
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-Y}"
    local answer

    if [[ "$default" == "Y" ]]; then
        read -r -p "$prompt (Y/n): " answer
        answer="${answer:-Y}"
    else
        read -r -p "$prompt (y/N): " answer
        answer="${answer:-N}"
    fi

    [[ "$answer" =~ ^[Yy]$ ]]
}

choose_example_file() {
    if [[ -f "$GENERIC_EXAMPLE" && -f "$NFSN_EXAMPLE" ]]; then
        echo >&2
        echo "No wp-maintenance*.conf files found in $SCRIPT_BASE_DIR." >&2
        echo "Choose an example to copy:" >&2
        echo "  1) Generic / cPanel example  - recommended for cPanel and most hosts" >&2
        echo "  2) NFSN example              - recommended for NearlyFreeSpeech.NET" >&2
        while true; do
            read -r -p "Enter 1 or 2 [1]: " choice
            choice="${choice:-1}"
            case "$choice" in
                1) printf '%s\n' "$GENERIC_EXAMPLE"; return 0 ;;
                2) printf '%s\n' "$NFSN_EXAMPLE"; return 0 ;;
                *) echo "Please enter 1 or 2." >&2 ;;
            esac
        done
    elif [[ -f "$GENERIC_EXAMPLE" ]]; then
        printf '%s\n' "$GENERIC_EXAMPLE"
    elif [[ -f "$NFSN_EXAMPLE" ]]; then
        printf '%s\n' "$NFSN_EXAMPLE"
    else
        return 1
    fi
}

# Step 6: Handle configuration
load_conf_files() {
    local conf_list_file
    conf_list_file="$(mktemp)" || abort "Aborting - unable to create temporary file."

    find_conf_files > "$conf_list_file"

    CONF_FILES=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && CONF_FILES+=("$line")
    done < "$conf_list_file"

    rm -f "$conf_list_file"
}

load_conf_files

if [[ "${#CONF_FILES[@]}" -eq 0 ]]; then
    if $QUIET; then
        abort "Aborting - no wp-maintenance*.conf files found in $SCRIPT_BASE_DIR"
    fi

    EXAMPLE_SOURCE="$(choose_example_file)" || abort "Aborting - no example config file found in $REPO_DIR"
    NEW_CONF="$SCRIPT_BASE_DIR/wp-maintenance.conf"

    echo
    if prompt_yes_no "Create $NEW_CONF from $(basename "$EXAMPLE_SOURCE") now?" "Y"; then
        cp "$EXAMPLE_SOURCE" "$NEW_CONF"
        echo "Created $NEW_CONF"
        echo "Please edit DOMAIN and other settings before running wp-maintenance.sh."
    else
        abort "Aborting - no configuration file present."
    fi

    load_conf_files
fi

if [[ "${#CONF_FILES[@]}" -eq 0 ]]; then
    abort "Aborting - no wp-maintenance*.conf files found in $SCRIPT_BASE_DIR"
fi

for CONF_DEST in "${CONF_FILES[@]}"; do
    if ! grep -q "^RETENTION_WPCLI=" "$CONF_DEST"; then
        if $QUIET; then
            abort "Aborting - RETENTION_WPCLI is missing from $CONF_DEST"
        fi

        echo
        echo "Config missing RETENTION_WPCLI: $CONF_DEST"
        if prompt_yes_no "Insert RETENTION_WPCLI=90 into this config now?" "Y"; then
            CONFIG_BACKUP="$CONF_DEST.bak.$(date +%Y%m%d_%H%M%S)"
            cp "$CONF_DEST" "$CONFIG_BACKUP"
            echo "Backed up existing config to $CONFIG_BACKUP"

            if grep -q "^RETENTION_LOGS=" "$CONF_DEST"; then
                awk '
                    /^RETENTION_LOGS=/ {
                        print
                        print "RETENTION_WPCLI=90 # days to keep WP-CLI caches (default 90 if not set)"
                        next
                    }
                    { print }
                ' "$CONF_DEST" > "$CONF_DEST.tmp"
            else
                awk '
                    { print }
                    END {
                        print "RETENTION_WPCLI=90 # days to keep WP-CLI caches (default 90 if not set)"
                    }
                ' "$CONF_DEST" > "$CONF_DEST.tmp"
            fi

            mv "$CONF_DEST.tmp" "$CONF_DEST"
            echo "Inserted RETENTION_WPCLI=90 into $CONF_DEST"
        else
            abort "Aborting - RETENTION_WPCLI is required in $CONF_DEST"
        fi
    fi
done

# Final output only if not in quiet mode
if ! $QUIET; then
    echo
    echo "Setup complete!"
    echo "Main script: $SCRIPT_DEST"
    echo "Current version: $(git rev-parse --short HEAD)"
    echo
    echo "You can now run the maintenance script with:"
    echo "  $SCRIPT_DEST"
    echo "  or with a custom config: $SCRIPT_DEST -c /path/to/custom.conf"
    echo
    echo "Run a dry test with:"
    echo "  $SCRIPT_DEST --dry-run"
fi

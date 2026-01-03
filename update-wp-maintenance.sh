#!/bin/bash
set -euo pipefail

REPO_DIR="/home/private/wordpress-maintenance-script"
SCRIPT_DEST="/home/private/wp-maintenance.sh"  
CONFIG_EXAMPLE="/home/private/wp-maintenance.conf"

cd "$REPO_DIR"
git pull origin main

cp wp-maintenance.sh "$SCRIPT_DEST"
chmod 700 "$SCRIPT_DEST" 

echo "wp-maintenance.sh updated and installed to $SCRIPT_DEST"
echo "Commit: $(git rev-parse --short HEAD)"

# Help NFSN users get started
if [[ ! -f "$CONFIG_EXAMPLE" ]]; then
    echo
    echo "No config found. Creating one from the NFSN example:"
    cp wp-maintenance.conf.nfsn-example "$CONFIG_EXAMPLE"
    echo "- Config created at $CONFIG_EXAMPLE"
    echo "   Please review and edit DOMAIN and other settings!"
fi

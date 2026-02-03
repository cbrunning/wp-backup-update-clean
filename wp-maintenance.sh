#!/bin/bash
set -euo pipefail

# ==================== Configuration Loading ====================
DEFAULT_CONFIG="/home/private/wp-maintenance.conf"
CONFIG_FILE="$DEFAULT_CONFIG"

while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --config requires a file path" >&2
                exit 1
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run|--backup-only|--quiet|--cron)
            break
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--config /path/to.conf] [--dry-run] [--backup-only] [--quiet|--cron]" >&2
            exit 1
            ;;
    esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    echo "       Default location: $DEFAULT_CONFIG" >&2
    exit 1
fi

# shellcheck source=/home/private/wp-maintenance.conf
source "$CONFIG_FILE"

# Set default for RETENTION_WPCLI if not defined
: "${RETENTION_WPCLI:=90}"

required_vars=(
    DOMAIN WP_ROOT TMP_DIR BACKUP_DIR WP_CLI_CACHE
    LOG_DIR MAINT_LOG RETENTION_BACKUPS RETENTION_LOGS
    UPDATE_SCRIPT
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: Required variable '$var' is not set in $CONFIG_FILE" >&2
        exit 1
    fi
done

# ==================== Flags ====================
DRY_RUN=false
BACKUP_ONLY=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --backup-only)
            BACKUP_ONLY=true
            shift
            ;;
        --quiet|--cron)
            QUIET=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--config /path/to.conf] [--dry-run] [--backup-only] [--quiet|--cron]" >&2
            exit 1
            ;;
    esac
done

if ! $DRY_RUN; then
    mkdir -p "$TMP_DIR" "$BACKUP_DIR" "$LOG_DIR"
fi

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="${DOMAIN}_wordpress_${TIMESTAMP}.tar.gz"
TMP_BACKUP="${TMP_DIR}/${BACKUP_NAME}"
DB_DUMP="${TMP_DIR}/${DOMAIN}_db_${TIMESTAMP}.sql"
DB_LOG="${TMP_DIR}/${DOMAIN}_db_export_${TIMESTAMP}.log"
XMLRPC_ORIG="${WP_ROOT}/xmlrpc.php"
XMLRPC_DISABLED="${WP_ROOT}/xmlrpc.php.disabled"

log() {
    local message="$(date +"%Y-%m-%d %H:%M:%S") - $*"
    echo "$message" >> "$MAINT_LOG"
    if ! $QUIET; then
        echo "$message"
    fi
}

dry_log() {
    if $DRY_RUN && ! $QUIET; then
        echo "[DRY-RUN] $*"
    fi
}

log "========================================"
log "Starting WordPress maintenance for $DOMAIN"
log "Using config file: $CONFIG_FILE"
log "Mode: Dry-run=$DRY_RUN, Backup-only=$BACKUP_ONLY, Quiet=$QUIET"

# ==================== Backup ====================
log "Creating backup..."

if $DRY_RUN; then
    dry_log "Would change to directory: $WP_ROOT"
else
    cd "$WP_ROOT"
fi

dry_log "Would export database to $DB_DUMP and log to $DB_LOG"
if ! $DRY_RUN; then
    wp db export - --path="$WP_ROOT" 2>&1 | tee "$DB_LOG" > "$DB_DUMP"
fi

dry_log "Would create archive: $TMP_BACKUP"
if ! $DRY_RUN; then
    tar czf "$TMP_BACKUP" \
        --exclude='wp-content/cache/*' \
        --exclude='wp-content/uploads/*cache*' \
        --exclude='*.log' \
        --exclude='backups' \
        --exclude='.git' \
        -C "$WP_ROOT" . \
        -C "$TMP_DIR" "$(basename "$DB_DUMP")" "$(basename "$DB_LOG")"

    log "Verifying backup integrity..."
    gzip -t "$TMP_BACKUP"
    log "Backup integrity verified"

    BACKUP_SIZE=$(du -h "$TMP_BACKUP" | cut -f1)
    log "Backup created: $BACKUP_DIR/$BACKUP_NAME (size: $BACKUP_SIZE)"

    mv "$TMP_BACKUP" "$BACKUP_DIR/"
    rm "$DB_DUMP" "$DB_LOG"
fi

dry_log "Would delete backups older than $RETENTION_BACKUPS days"
if ! $DRY_RUN; then
    find "$BACKUP_DIR" -type f -mtime +"$RETENTION_BACKUPS" -delete 2>/dev/null || true
    log "Deleted backups older than $RETENTION_BACKUPS days"
fi

if $BACKUP_ONLY; then
    log "Backup-only mode: Skipping updates and post-update cleanup"
    log "Maintenance completed"
    log "========================================"
    exit 0
fi

# ==================== Update ====================
log "Running updates via $UPDATE_SCRIPT..."

if $DRY_RUN; then
    dry_log "Would execute: $UPDATE_SCRIPT --path $WP_ROOT"
else
    "$UPDATE_SCRIPT" --path "$WP_ROOT" 2>&1
    log "Updates completed (or none needed)"
fi

# ==================== Post-update Cleanup ====================
log "Starting post-update cleanup..."

if [[ -d "$WP_CLI_CACHE" ]]; then
    dry_log "Would clean WP-CLI caches older than $RETENTION_WPCLI days"
    if ! $DRY_RUN; then
        find "$WP_CLI_CACHE"/{core,plugin,theme} -type f -mtime +"$RETENTION_WPCLI" -delete 2>/dev/null || true
        log "Cleaned WP-CLI caches older than $RETENTION_WPCLI days"
    fi
fi

if [[ -d "$LOG_DIR" ]]; then
    dry_log "Would clean logs older than $RETENTION_LOGS days"
    if ! $DRY_RUN; then
        find "$LOG_DIR" -type f -name '*.log' -mtime +"$RETENTION_LOGS" -delete 2>/dev/null || true
        log "Cleaned logs older than $RETENTION_LOGS days"
    fi
fi

dry_log "Would flush WordPress object cache"
if ! $DRY_RUN; then
    wp cache flush --path="$WP_ROOT" --quiet || true
    log "Flushed WordPress object cache"
fi

if [[ -r "$XMLRPC_ORIG" && ! -e "$XMLRPC_DISABLED" ]]; then
    if $DRY_RUN; then
        dry_log "Would rename $XMLRPC_ORIG → $XMLRPC_DISABLED"
    else
        mv "$XMLRPC_ORIG" "$XMLRPC_DISABLED"
        log "Disabled xmlrpc.php by renaming to xmlrpc.php.disabled"
    fi
else
    log "xmlrpc.php already disabled or not present"
fi

log "Full maintenance completed successfully"
log "========================================"
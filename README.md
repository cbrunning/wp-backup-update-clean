# wp-backup-update-clean  

Bash scripts for automated WordPress maintenance.  
  
Features include:  
- Full site + database backup with integrity checks and size reporting  
- Updates via a configurable update script  
- Cleanup of old backups, maintenance logs, and WP-CLI cache  
- Dry-run mode  
- Quiet / cron mode with reduced output
- External config file support  
- Backup-only mode  
  
Tested on NearlyFreeSpeech.NET (NFSN), with growing support for more generic hosting environments such as cPanel.  
 
## Recommended layout  
 
The scripts are intended to live under:  
  
```plaintext  
$HOME/wp-maintenance/  
├── wp-maintenance.sh  
├── wp-maintenance.conf  
├── wpcli-update-placeholder.sh  
├── wpcli-update-basic.sh  
├── repos/  
│   └── wp-backup-update-clean/  
├── wordpress-backups/  
└── wp-maintenance-logs/
```
 
## Quick start
```bash
mkdir -p "$HOME/wp-maintenance/repos"  
cd "$HOME/wp-maintenance/repos"  
git clone https://github.com/cbrunning/wp-backup-update-clean.git  
"$HOME/wp-maintenance/repos/wp-backup-update-clean/update-wp-maintenance.sh"
```
 
The update helper can:
 
- clone or update the repository
- install `wp-maintenance.sh`
- help create an initial config file from an example
- prompt to create required directories
- create a safe placeholder update script
- optionally create a basic WP-CLI update script
 
## Example configs
 
The repository includes two example config files:

- `wp-maintenance-generic.conf.example` - recommended for cPanel and most non-NFSN hosts
- `wp-maintenance-nfsn.conf.example` - recommended for NearlyFreeSpeech.NET

After setup completes, edit:
 
```
$HOME/wp-maintenance/wp-maintenance.conf
```
 
At minimum, set your `DOMAIN`, `WP_ROOT`, and review the other paths and retention settings.
 
## Update scripts
 
`wp-maintenance.sh` runs whatever is defined in `UPDATE_SCRIPT`.
 
By default, the example configs can point to a placeholder script for safety during initial setup. Replace `UPDATE_SCRIPT` with the WordPress update script you actually want to run.
 
Examples:
 
- NFSN: `/usr/local/bin/wp-update.sh`
- Generic hosts: `$HOME/wp-maintenance/wpcli-update-basic.sh`
- Or your own custom script
 
## Logging
 
Maintenance logs are written to a dedicated log directory, and log filenames are generated per run. This makes it easier to separate maintenance logs from unrelated logs and remove old logs based on the configured retention period.
 
## Running the script
 
Dry run:
 
`$HOME/wp-maintenance/wp-maintenance.sh --dry-run`
 
Use a custom config:
 
`$HOME/wp-maintenance/wp-maintenance.sh -c /path/to/custom.conf`
 
Backup only:
 
`$HOME/wp-maintenance/wp-maintenance.sh --backup-only`
 
## Notes
 
- The helper and runtime scripts are designed around a private working directory under `$HOME/wp-maintenance`.
- Temporary backups default to `/home/tmp/backups` on NFSN and `$HOME/tmp/backups` on more typical hosts.
- The helper supports multiple `wp-maintenance*.conf` files in the install directory.
 
## License
 
GNU General Public License v2.0 or later (GPLv2+). See `LICENSE` for details.

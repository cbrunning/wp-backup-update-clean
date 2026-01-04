# wp-backup-update-clean

Bash script for automated WordPress maintenance:

- Creates a full site + database backup (with integrity check and size reporting)  
- Runs updates via a customizable update script (typically WordPress core, plugin, and theme updates using WP-CLI)  
- Performs post-update cleanup (caches, old logs, WP-CLI cache)  

Designed for scheduled cron jobs, with support for:
- Dry-run mode  
- Quiet/cron mode (output only on updates or errors)  
- External configuration file  
- Backup-only mode  

Tested on NearlyFreeSpeech.NET (NFSN) accounts. The default configuration uses NFSN's provided update script, but you can easily replace it with your own WP-CLI-based updater.

### Recommended Directory Layout on NearlyFreeSpeech.NET (NFSN)

For a clean separation between source code and runtime files:

```plaintext
/home/private/
├── wp-maintenance.sh                  # Script called by cron
├── wp-maintenance.conf                # Your site-specific configuration
├── repos/                             # Git repositories (created automatically if needed)
│   └── wp-backup-update-clean/        # Cloned repository
└── wordpress-maintenance-backups/     # Final backups (created automatically)
```

The included `update-wp-maintenance.sh` helper script will prompt to create `/home/private/repos` (and other required directories) if missing.

If you prefer a different location, adjust the paths in the update script or clone manually.

### Quick Start on NFSN

Create the repo directory if needed, and enter the directory:
```bash
cd /home/private/repos || mkdir -p /home/private/repos && cd /home/private/repos
```
### Clone the Repository

Use HTTPS (no authentication required):
```bash
git clone https://github.com/cbrunning/wp-backup-update-clean.git
```
Or use SSH (requires a GitHub account with an SSH key added):
```bash
git clone git@github.com:cbrunning/wp-backup-update-clean.git
```
Then run the update helper script:
```bash
cd /home/private
/home/private/repos/wp-backup-update-clean/update-wp-maintenance.sh
```
Notes:

- The helper script will guide you through creating any missing directories and the initial configuration file
- Using SSH for `git clone` is recommended. See [GitHub Docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) for info on key setup, if needed

After setup completes, **edit `/home/private/wp-maintenance.conf`** to set your `DOMAIN` and review other paths/settings for your site.

You can then test with a dry run:
```bash
/home/private/wp-maintenance.sh --dry-run
```

### License

GNU General Public License v2.0 or later (GPLv2+). See [LICENSE](LICENSE) for details.

---

More documentation, usage examples, and configuration guides coming soon.

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

Tested on NearlyFreeSpeech.NET (NFSN) accounts. The default configuration uses NFSN's provided update script, but you can easily point it to your own WP-CLI updater.

### License

GNU General Public License v2.0 or later (GPLv2+). See [LICENSE](LICENSE) for details.

---

Full documentation, usage examples, and configuration guides are in progress.
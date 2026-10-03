# MirrorBar

A tiny native macOS menu bar app (one Swift file, no dependencies) that shows the status of a folder/disk-image **mirror** and lets you **safely eject** the mirror drive.

```
🔄 55%      ← syncing (percentage copied)
✅          ← in sync
⚠️          ← last sync failed
💾          ← mirror drive not connected
```

Click it to see status, last sync time, GB copied, open the status file, or **eject the drive safely**:
it stops any process writing to the drive, detaches disk images stored on it, ejects it, and notifies you when it's safe to unplug.

## Build
```bash
./build.sh            # needs Xcode Command Line Tools
open MirrorBar.app
```

## Configure
On first launch MirrorBar asks you to pick:
1. **Source** — the main folder or disk image (e.g. `~/Disks/MyDisk.sparsebundle`)
2. **Mirror** — its copy on the backup drive (e.g. `/Volumes/Backup/MyDisk.sparsebundle`)

It remembers them. Change them anytime from the menu: **Configure…**
The drive to eject is detected from the mirror path (`/Volumes/<Drive>`).

Optional status file (written by your sync script), default `<mirror folder>/<name> - LAST SYNC.txt`:
```
Status:    🔄 SYNCING…   |  ✅ IN SYNC  |  ⚠️ LAST SYNC FAILED
Last sync: 2026-10-03 02:55:12
```
Without it, MirrorBar shows the percentage copied (mirror size vs. source size).

Advanced (Terminal):
```bash
defaults write com.joelveloz.mirrorbar Source "/path/source"
defaults write com.joelveloz.mirrorbar Mirror "/Volumes/Backup/copy"
defaults write com.joelveloz.mirrorbar StatusFile "/path/status.txt"   # optional
defaults write com.joelveloz.mirrorbar Volume "/Volumes/Backup"        # optional
```

## Start at login
System Settings → General → Login Items → add `MirrorBar.app`.

## License
MIT

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
```bash
defaults write com.joelveloz.mirrorbar Source     "~/Discos/MyDisk.sparsebundle"
defaults write com.joelveloz.mirrorbar Mirror     "/Volumes/Backup/MyDisk.sparsebundle"
defaults write com.joelveloz.mirrorbar StatusFile "/Volumes/Backup/MyDisk - LAST SYNC.txt"
defaults write com.joelveloz.mirrorbar Volume     "/Volumes/Backup"
```
The status file is plain text written by your sync script, with lines like:
```
Status:    🔄 SYNCING…   |  ✅ IN SYNC  |  ⚠️ LAST SYNC FAILED
Last sync: 2026-10-03 02:55:12
```

## Start at login
System Settings → General → Login Items → add `MirrorBar.app`.

## License
MIT

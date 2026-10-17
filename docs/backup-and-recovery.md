# Hinopt Restaurant POS — Backup and Disaster Recovery Procedure

This document outlines the backup schedules, data integrity verification, and disaster recovery procedures for the Hinopt Restaurant POS installation.

> **Single Point of Failure Note:** The Windows Counter PC runs the local PostgreSQL operational database. If the PC hardware fails, orders and bills cannot be processed until the local server is restored. Reliable, automated backups and spare machine recovery readiness are therefore mandatory.

---

## 1. Automated Scheduled Backup

### Backup Script (`backup-pos.ps1`)
Store this script on the Counter PC (e.g., `C:\Hinopt\scripts\backup-pos.ps1`):

```powershell
$Date = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = "D:\HinoptBackups\Daily"
$ExtDriveDir = "E:\HinoptBackups" # External USB Drive
$DbName = "curry_leaf_pos"
$BackupFile = "$BackupDir\hinopt_backup_$Date.sql.gz"

if (!(Test-Path -Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force
}

# Run pg_dump with compression
& "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe" -U postgres -h localhost -d $DbName | gzip > $BackupFile

# Copy to external drive if available
if (Test-Path -Path $ExtDriveDir) {
    Copy-Item -Path $BackupFile -Destination $ExtDriveDir -Force
}

# Rotate backups: delete backups older than 30 days
Get-ChildItem -Path $BackupDir -Filter "*.sql.gz" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
```

### Windows Task Scheduler Setup
1. Open **Task Scheduler** on the Counter PC.
2. Create a basic task named `Hinopt_POS_Daily_Backup`.
3. Set trigger to **Daily at 02:00 AM** (after restaurant closing).
4. Set action to start `powershell.exe -ExecutionPolicy Bypass -File C:\Hinopt\scripts\backup-pos.ps1`.

---

## 2. Retention Policy

| Tier | Frequency | Retention Period | Storage Target |
|---|---|---|---|
| **Daily** | Every night at 2:00 AM | 30 days | Secondary local drive (e.g., `D:`) |
| **Off-machine** | Every night | 90 days | External USB Flash drive (e.g., `E:`) |
| **Monthly Archive** | End of each month | 7 years (for GST/Tax compliance) | Encrypted cloud storage (when online) |

---

## 3. Database Restoration Procedure

In the event of database corruption or hardware replacement:

### Step 1: Install PostgreSQL on Replacement Machine
1. Install PostgreSQL LTS (v15 or v16).
2. Set `postgres` user password to match configuration.
3. Create the operational database:
   ```cmd
   createdb -U postgres curry_leaf_pos
   ```

### Step 2: Restore from Latest Backup
```powershell
# Decompress and pipe to psql
gunzip -c D:\HinoptBackups\Daily\hinopt_backup_20261017_020000.sql.gz | psql -U postgres -d curry_leaf_pos
```

### Step 3: Verify Restoration Integrity
Run verification queries:
```sql
SELECT count(*) FROM restaurant_tables;
SELECT count(*) FROM menu_items;
SELECT count(*) FROM bills;
SELECT count(*) FROM payments;
```

### Step 4: Verify Local API & Connect Captain Tablets
1. Start the local API service:
   ```cmd
   npm run start:api
   ```
2. Verify `http://localhost:4000/api/health` reports `"status": "healthy"`.
3. Verify Captain Android tablets connect over Wi-Fi and display table status.

---

## 4. Disaster Recovery Checklist

- [ ] Counter PC has a static LAN IP or DHCP reservation configured in the router.
- [ ] At least one external backup copy exists outside the primary drive.
- [ ] Restore procedure has been tested in a dry-run environment.
- [ ] Router Wi-Fi credentials and IP reservations are documented on-site.

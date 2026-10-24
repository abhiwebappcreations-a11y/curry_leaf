import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';

class BackupRestoreDialog extends StatefulWidget {
  final CounterProvider provider;

  const BackupRestoreDialog({super.key, required this.provider});

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _jsonInputController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _localSnapshots = [];
  Map<String, dynamic>? _cloudStatus;
  String? _statusMessage;
  bool _isSuccessMessage = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSnapshots();
    _loadCloudStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jsonInputController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshots() async {
    final list = await widget.provider.listBackupSnapshots();
    if (mounted) {
      setState(() => _localSnapshots = list);
    }
  }

  Future<void> _loadCloudStatus() async {
    final status = await widget.provider.getCloudBackupStatus();
    if (mounted) {
      setState(() => _cloudStatus = status);
    }
  }

  Future<void> _handleCloudSync() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final res = await widget.provider.syncCloudBackup();
    setState(() => _isLoading = false);

    if (res != null) {
      final fileName = res['fileName'] as String? ?? 'backup.enc';
      final size = (res['sizeBytes'] ?? 0) ~/ 1024;
      setState(() {
        _statusMessage = 'Backup encrypted with AES-256-GCM and synced to Hinopt Google Drive!\nFile: $fileName ($size KB) • Data is 100% private and encrypted.';
        _isSuccessMessage = true;
      });
      _loadCloudStatus();
      _loadSnapshots();
    } else {
      setState(() {
        _statusMessage = 'Failed to sync to cloud. Local encrypted copy saved safely on disk.';
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _handleCloudRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Google Drive Restore'),
        content: const Text(
          'This will pull the latest AES-256 encrypted backup from Hinopt Google Drive, decrypt it with your restaurant license key, and restore all tables, menu, and orders.\n\nDo you want to proceed?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore from Cloud', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final ok = await widget.provider.restoreCloudBackup();
    setState(() => _isLoading = false);

    if (ok) {
      setState(() {
        _statusMessage = 'Database restored successfully from Hinopt Google Drive! All dishes, tables, and past bills are active.';
        _isSuccessMessage = true;
      });
    } else {
      setState(() {
        _statusMessage = 'Could not restore from cloud. Please check internet connection or license status.';
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _handleExport() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final res = await widget.provider.exportBackup();
    setState(() => _isLoading = false);

    if (res != null) {
      final snapshotPath = res['snapshotPath'] as String? ?? '';
      setState(() {
        _statusMessage = 'Backup created successfully! Saved to:\n$snapshotPath\n\nCopy this file to your USB drive.';
        _isSuccessMessage = true;
      });
      _loadSnapshots();
    } else {
      setState(() {
        _statusMessage = 'Failed to generate backup. Please check local server connection.';
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _handleRestoreJson() async {
    final text = _jsonInputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _statusMessage = 'Please paste the backup JSON content or select an existing snapshot below.';
        _isSuccessMessage = false;
      });
      return;
    }

    try {
      final data = jsonDecode(text);
      final payload = data['backup'] ?? data;

      setState(() => _isLoading = true);
      final ok = await widget.provider.restoreBackup(payload as Map<String, dynamic>);
      setState(() => _isLoading = false);

      if (ok) {
        setState(() {
          _statusMessage = 'Database restored successfully! All tables, menu, and orders are live.';
          _isSuccessMessage = true;
          _jsonInputController.clear();
        });
      } else {
        setState(() {
          _statusMessage = 'Server rejected restore payload. Please verify backup file.';
          _isSuccessMessage = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Invalid JSON: $e';
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _handleRestoreSnapshot(String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'Restoring snapshot "$fileName" will replace current tables, menu, and active orders with this backup.\n\nDo you want to proceed?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Snapshot', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final ok = await widget.provider.restoreSnapshot(fileName);
    setState(() => _isLoading = false);

    if (ok) {
      setState(() {
        _statusMessage = 'Database restored cleanly from "$fileName"!';
        _isSuccessMessage = true;
      });
    } else {
      setState(() {
        _statusMessage = 'Failed to restore snapshot. Please verify file on disk.';
        _isSuccessMessage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 660,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Database Backup & Cloud Restore',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'AES-256-GCM Encrypted Google Drive Sync & Offline USB Protection',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 14),

            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.cloud_done_outlined, size: 18), text: 'Google Drive Sync'),
                Tab(icon: Icon(Icons.usb_rounded, size: 18), text: 'USB Export'),
                Tab(icon: Icon(Icons.settings_backup_restore, size: 18), text: 'Manual Restore'),
              ],
            ),
            const SizedBox(height: 12),

            if (_statusMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccessMessage ? AppColors.successBg : AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccessMessage ? AppColors.success : AppColors.error,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccessMessage ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccessMessage ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isSuccessMessage ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCloudTab(),
                  _buildExportTab(),
                  _buildRestoreTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudTab() {
    final lastSyncStr = _cloudStatus?['lastSyncedAt'] != null
        ? DateFormat('dd MMM yyyy • hh:mm:ss a').format(DateTime.tryParse(_cloudStatus!['lastSyncedAt']) ?? DateTime.now())
        : 'Never synced yet';

    final sizeKb = ((_cloudStatus?['sizeBytes'] ?? 0) / 1024).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero-Knowledge AES-256-GCM Military Encryption',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your data is encrypted locally with your restaurant license key before upload. Nobody at Google or outside can see your customer phone numbers, GST invoices, or sales figures.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 0,
          color: AppColors.surfaceMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildInfoRow('Storage Destination:', 'Hinopt Google Drive Storage Bridge'),
                const Divider(height: 16),
                _buildInfoRow('Encryption Cipher:', 'AES-256-GCM Authenticated Cipher'),
                const Divider(height: 16),
                _buildInfoRow('Last Cloud Sync:', lastSyncStr),
                const Divider(height: 16),
                _buildInfoRow('Encrypted File Size:', '$sizeKb KB (Under 50 KB)'),
              ],
            ),
          ),
        ),
        const Spacer(),

        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleCloudSync,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cloud_upload, size: 20),
          label: Text(
            _isLoading ? 'ENCRYPTING & UPLOADING...' : 'SYNC ENCRYPTED BACKUP TO GOOGLE DRIVE NOW',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: _isLoading ? null : _handleCloudRestore,
          icon: const Icon(Icons.settings_backup_restore, size: 18, color: AppColors.primary),
          label: const Text(
            '1-Click Restore From Latest Cloud Backup',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size.fromHeight(42),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildExportTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.usb_rounded, size: 20, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline Safety: Keep a ₹250 USB thumb drive permanently plugged into the counter PC. Export a snapshot daily at closing for zero-internet backup.',
                  style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleExport,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.backup_outlined, size: 20),
          label: Text(
            _isLoading ? 'GENERATING SNAPSHOT...' : 'CREATE USB BACKUP SNAPSHOT NOW',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'Existing Local Snapshots on this PC:',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),

        Expanded(
          child: _localSnapshots.isEmpty
              ? const Center(
                  child: Text(
                    'No backups generated yet.\nClick the button above to create your first backup.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: _localSnapshots.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _localSnapshots[index];
                    final name = item['name'] as String? ?? 'backup.json';
                    final size = item['sizeKb'] ?? 0;
                    final date = item['createdAt'] != null
                        ? DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.tryParse(item['createdAt']) ?? DateTime.now())
                        : '';

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary, size: 22),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      subtitle: Text('$date • ${size}KB', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'Copy Filename',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: name));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Filename copied to clipboard!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRestoreTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFF57F17)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Moving to another PC? Install the app on the new PC, connect your USB drive, and select the backup file below to restore 100% of your restaurant floor plan, menu items, and history.',
                  style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF5D4037)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'Option A: Restore from Local Snapshot on Disk',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),

        SizedBox(
          height: 100,
          child: _localSnapshots.isEmpty
              ? const Center(
                  child: Text(
                    'No local snapshots found.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: _localSnapshots.length,
                  itemBuilder: (context, index) {
                    final item = _localSnapshots[index];
                    final name = item['name'] as String? ?? 'backup.json';
                    final date = item['createdAt'] != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(item['createdAt']) ?? DateTime.now())
                        : '';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        dense: true,
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        subtitle: Text(date, style: const TextStyle(fontSize: 10)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: _isLoading ? null : () => _handleRestoreSnapshot(name),
                          child: const Text('Restore', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),

        const Text(
          'Option B: Paste USB Backup JSON Content',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),

        Expanded(
          child: TextField(
            controller: _jsonInputController,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Open your backup .json file in Notepad, copy its content, and paste it here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleRestoreJson,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.settings_backup_restore, size: 18),
          label: const Text('RESTORE DATABASE FROM PASTED JSON', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}

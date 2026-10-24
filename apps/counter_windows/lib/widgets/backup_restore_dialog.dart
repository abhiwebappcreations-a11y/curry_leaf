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
  String? _statusMessage;
  bool _isSuccessMessage = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSnapshots();
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
          'Restoring snapshot "$fileName" will replace the current tables, menu, and active orders with this backup.\n\nDo you want to proceed?',
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
        width: 620,
        height: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.usb_rounded, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Database Backup & USB Restore',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Protect restaurant data offline or migrate to a new computer in 30 seconds',
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
                Tab(icon: Icon(Icons.file_download_outlined, size: 18), text: 'Export / USB Backup'),
                Tab(icon: Icon(Icons.settings_backup_restore, size: 18), text: 'Restore to New PC'),
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
              Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recommended: Keep a small USB pendrive plugged into the counter PC. Export a backup daily at shift closing. If this PC ever fails, simply plug the USB into any other PC and restore.',
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
            _isLoading ? 'GENERATING SNAPSHOT...' : 'CREATE BACKUP SNAPSHOT NOW',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 16),

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
          height: 110,
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

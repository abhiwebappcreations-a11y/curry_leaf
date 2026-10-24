import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/pos_provider.dart';
import '../theme/app_colors.dart';
import 'status_pill.dart';

class OrderSummarySheet extends StatelessWidget {
  const OrderSummarySheet({super.key});

  void _showCancelDialog(BuildContext context, OrderItem item) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Item Cancellation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item: ${item.name} (Qty: ${item.quantity})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Reason is required for Kitchen/Counter audit:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Guest changed mind / Wrong order',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                context.read<PosProvider>().requestItemCancellation(item, reason);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cancellation request recorded for Counter approval.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            child: const Text('Request Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, OrderItem item) {
    final noteController = TextEditingController(text: item.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kitchen Note: ${item.name}'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Less oil, extra spicy, no onion',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosProvider>();
    final order = provider.currentOrder;
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    );

    if (order == null) return const SizedBox.shrink();

    final draftItems = order.draftItems;
    final submittedItems = order.submittedItems;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Drag bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${provider.currentTable?.name} • Order Cart',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${draftItems.length} Draft Items • ${submittedItems.length} in Kitchen',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currencyFormatter.format(order.totalRupees),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              const Divider(color: AppColors.borderLight, height: 20),

              // Items List (Limited Max Height)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Draft Items Section
                    if (draftItems.isNotEmpty) ...[
                      const Row(
                        children: [
                          Icon(Icons.edit_note, size: 16, color: AppColors.warning),
                          SizedBox(width: 6),
                          Text(
                            'NEW DRAFT ITEMS (NOT SENT TO KITCHEN)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...draftItems.map((item) => _buildDraftItemRow(context, provider, item, currencyFormatter)),
                      const SizedBox(height: 12),
                    ],

                    // Previously Submitted Items Section
                    if (submittedItems.isNotEmpty) ...[
                      const Row(
                        children: [
                          Icon(Icons.outdoor_grill, size: 16, color: AppColors.info),
                          SizedBox(width: 6),
                          Text(
                            'ALREADY SENT TO KITCHEN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.info,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...submittedItems.map((item) => _buildSubmittedItemRow(context, item, currencyFormatter)),
                    ],

                    if (draftItems.isEmpty && submittedItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No items in order yet. Tap items on the menu to add.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action Button: Send to Kitchen
              if (draftItems.isNotEmpty)
                ElevatedButton(
                  onPressed: provider.isSubmittingKot
                      ? null
                      : () async {
                          try {
                            final ticket = await provider.sendDraftToKitchen();
                            if (context.mounted && ticket != null) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 2),
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('Order dispatched! ${ticket.kotNumber} printed to kitchen.'),
                                    ],
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.error,
                                  duration: const Duration(seconds: 4),
                                  content: Row(
                                    children: [
                                      const Icon(Icons.lock, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(e.toString().replaceAll('Exception: ', '')),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: provider.isSubmittingKot
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'SEND TO KITCHEN (KOT) • ${draftItems.length} ITEMS',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                )
              else
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Back to Tables'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftItemRow(
    BuildContext context,
    PosProvider provider,
    OrderItem item,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.selectedVariant != null)
                      Text(
                        'Variant: ${item.selectedVariant}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Text(
                        'Note: ${item.notes}',
                        style: const TextStyle(fontSize: 11, color: AppColors.warning),
                      ),
                  ],
                ),
              ),
              Text(
                currencyFormatter.format(item.totalRupees),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              // Quantity stepper
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => provider.updateDraftQuantity(item.id, -1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(Icons.remove, size: 14),
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    InkWell(
                      onTap: () => provider.updateDraftQuantity(item.id, 1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Icon(Icons.add, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.note_add_outlined, size: 16, color: AppColors.primary),
                tooltip: 'Add kitchen note',
                onPressed: () => _showAddNoteDialog(context, item),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                onPressed: () => provider.removeDraftItem(item.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedItemRow(
    BuildContext context,
    OrderItem item,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${item.quantity}x ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StatusPill.orderItemStatus(item.status),
                    if (item.sentAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('hh:mm a').format(item.sentAt!),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            currencyFormatter.format(item.totalRupees),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.warning),
            tooltip: 'Request cancellation',
            onPressed: () => _showCancelDialog(context, item),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

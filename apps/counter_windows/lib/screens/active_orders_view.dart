import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/counter_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/takeaway_order_dialog.dart';

class ActiveOrdersView extends StatelessWidget {
  const ActiveOrdersView({super.key});

  String _formatElapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CounterProvider>();
    final allOrders = provider.activeOrders;
    final activeFilter = provider.activeOrderFilter;
    final deliveryCount = allOrders.where((o) => o.isDelivery).length;
    final takeawayCount = allOrders.where((o) => o.isTakeaway && !o.isDelivery).length;
    final dineInCount = allOrders.where((o) => !o.isTakeaway && !o.isDelivery).length;
    final orders = allOrders.where((o) {
      if (activeFilter == 'delivery') return o.isDelivery;
      if (activeFilter == 'takeaway') return o.isTakeaway && !o.isDelivery;
      if (activeFilter == 'dine_in') return !o.isTakeaway && !o.isDelivery;
      return true;
    }).toList();
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 680;
        final horizontalPadding = isMobile ? 12.0 : 24.0;
        final verticalPadding = isMobile ? 12.0 : 20.0;

        return Container(
          color: AppColors.background,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title & Search
              if (isMobile) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: provider.isLicenseLocked ? null : () => _showTakeawayDialog(context, provider),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                          label: const Text('Takeaway'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: provider.isLicenseLocked ? null : () => provider.setActiveTab(CounterTab.tables),
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('Tables'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${orders.length} dining tables active in service',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Service Orders',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${orders.length} tables currently dining • Real-time orders sent by Captains',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: provider.isLicenseLocked ? null : () => _showTakeawayDialog(context, provider),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          label: const Text('+ New Takeaway / Parcel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE65100),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: provider.isLicenseLocked ? null : () => provider.setActiveTab(CounterTab.tables),
                          icon: const Icon(Icons.table_restaurant, size: 18),
                          label: const Text('Floor Tables / Fire KOT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Filter Tabs (All / Dine-in / Takeaway)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _buildFilterPill(
                      label: 'All Orders (${allOrders.length})',
                      isSelected: activeFilter == 'all',
                      onTap: () => provider.setActiveOrderFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: '🍽️ Dine-In Tables ($dineInCount)',
                      isSelected: activeFilter == 'dine_in',
                      onTap: () => provider.setActiveOrderFilter('dine_in'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterPill(
                      label: '🛍️ Takeaway / Parcel ($takeawayCount)',
                      isSelected: activeFilter == 'takeaway',
                      color: const Color(0xFFE65100),
                      onTap: () => provider.setActiveOrderFilter('takeaway'),
                    ),
                    if (provider.isOnlineOrderingEnabled || deliveryCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildFilterPill(
                        label: '🛵 Online Delivery ($deliveryCount)',
                        isSelected: activeFilter == 'delivery',
                        color: const Color(0xFF0D9488),
                        onTap: () => provider.setActiveOrderFilter('delivery'),
                      ),
                    ],
                  ],
                ),
              ),

              // Orders List with Pull-to-Refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refreshFromLiveApi(isManual: true),
                  color: AppColors.accent,
                  child: orders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'No active orders right now. New captain orders will appear here automatically.\n\nPull down to refresh.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: orders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return isMobile
                                ? _buildMobileOrderCard(context, provider, order, currencyFormatter)
                                : _buildDesktopOrderRow(context, provider, order, currencyFormatter);
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileOrderCard(
    BuildContext context,
    CounterProvider provider,
    RestaurantOrder order,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Table Badge, Order # & Time, Total Amount
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: order.isDelivery
                      ? const Color(0xFF0D9488)
                      : (order.isTakeaway ? const Color(0xFFE65100) : AppColors.primary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.tableName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Order #${order.id}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'KOT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${order.guestCount} Guests • ${_formatElapsed(order.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (order.isDelivery && order.deliveryAddress.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 11, color: Color(0xFF0D9488)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                order.deliveryAddress,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                currencyFormatter.format(order.totalRupees),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Items Chips Wrap
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: order.activeItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  '${item.quantity}x ${item.name}',
                  style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: provider.isLicenseLocked ? null : () => provider.selectOrder(order),
              icon: const Icon(Icons.receipt, size: 16),
              label: const Text('Finalize Bill & Settle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopOrderRow(
    BuildContext context,
    CounterProvider provider,
    RestaurantOrder order,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Badge
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: order.isDelivery
                  ? const Color(0xFF0D9488)
                  : (order.isTakeaway ? const Color(0xFFE65100) : AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  order.tableName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.guestCount} Guests',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Order Details & Items summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Order #${order.id}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'KOT IN KITCHEN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatElapsed(order.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Compact Items Tag Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: order.activeItems.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        '${item.quantity}x ${item.name}',
                        style: const TextStyle(
                          fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Total & Billing Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(order.totalRupees),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'GST Applicable',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: provider.isLicenseLocked ? null : () => provider.selectOrder(order),
                icon: const Icon(Icons.receipt, size: 16),
                label: const Text('Finalize Bill & Settle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  static Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : AppColors.border),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  static void _showTakeawayDialog(BuildContext context, CounterProvider provider) {
    TakeawayOrderDialog.show(context, provider);
  }
}

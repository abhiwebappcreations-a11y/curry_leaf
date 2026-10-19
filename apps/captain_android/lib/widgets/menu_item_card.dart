import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/menu_item_model.dart';
import '../theme/app_colors.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final int draftQuantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onCustomize;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.draftQuantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.onCustomize,
  });

  Widget _buildFallbackImagePlaceholder() {
    IconData iconData = Icons.restaurant;
    final catLower = item.category.toLowerCase();
    if (catLower.contains('starter') || catLower.contains('bite')) {
      iconData = Icons.tapas;
    } else if (catLower.contains('tandoor') || catLower.contains('grill')) {
      iconData = Icons.outdoor_grill;
    } else if (catLower.contains('biryani') || catLower.contains('rice')) {
      iconData = Icons.rice_bowl;
    } else if (catLower.contains('bread')) {
      iconData = Icons.bakery_dining;
    } else if (catLower.contains('beverage') || catLower.contains('drink') || catLower.contains('cooler')) {
      iconData = Icons.local_cafe;
    } else if (catLower.contains('dessert') || catLower.contains('sweet')) {
      iconData = Icons.icecream;
    } else if (catLower.contains('curry') || catLower.contains('main')) {
      iconData = Icons.dinner_dining;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: item.isVeg ? const Color(0xFFF1F8E9) : const Color(0xFFFBE9E7),
      child: Center(
        child: Icon(
          iconData,
          size: 38,
          color: item.isVeg ? AppColors.veg.withOpacity(0.4) : AppColors.nonVeg.withOpacity(0.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: draftQuantity > 0
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.border,
          width: draftQuantity > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Dish Picture Banner with Overlays
            SizedBox(
              height: 105,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.surfaceMuted,
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackImagePlaceholder(),
                    )
                  else
                    _buildFallbackImagePlaceholder(),

                  // Gradient scrim for contrast
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                            Colors.black.withOpacity(0.15),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left: Veg / Non-Veg Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.isVeg ? 'VEG' : 'NON-VEG',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Right: Customization Badge
                  if (item.variants.isNotEmpty || item.addons.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: onCustomize,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, size: 11, color: AppColors.primary),
                              SizedBox(width: 3),
                              Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    Text(
                      item.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Dish Name
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Description
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const Spacer(),

                    // Price & Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currencyFormatter.format(item.priceRupees),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (draftQuantity == 0)
                          ElevatedButton(
                            onPressed: onAdd,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(54, 30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 14),
                                SizedBox(width: 2),
                                Text(
                                  'ADD',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: onDecrement,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Icon(Icons.remove, size: 13, color: Colors.white),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '$draftQuantity',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: onIncrement,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                    child: Icon(Icons.add, size: 13, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

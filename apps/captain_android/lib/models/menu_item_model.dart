class MenuItem {
  final String id;
  final String name;
  final String category;
  final int pricePaise;
  final bool isVeg;
  final bool isAvailable;
  final String description;
  final List<String> variants;
  final List<String> addons;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePaise,
    required this.isVeg,
    this.isAvailable = true,
    this.description = '',
    this.variants = const [],
    this.addons = const [],
  });

  double get priceRupees => pricePaise / 100.0;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      pricePaise: json['pricePaise'] as int? ?? 0,
      isVeg: json['isVeg'] as bool? ?? true,
      isAvailable: json['isAvailable'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      variants: (json['variants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      addons: (json['addons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'pricePaise': pricePaise,
      'isVeg': isVeg,
      'isAvailable': isAvailable,
      'description': description,
      'variants': variants,
      'addons': addons,
    };
  }
}

class MenuItem {
  final String id;
  final String name;
  final String category;
  final int pricePaise;
  final bool isVeg;
  final bool isAvailable;
  final String description;
  final String? imageUrl;
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
    this.imageUrl,
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
      imageUrl: json['imageUrl'] as String?,
      variants: (json['variants'] as List<dynamic>?)?.map((e) {
        if (e is Map) return (e['name'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList() ?? [],
      addons: ((json['addOns'] ?? json['addons']) as List<dynamic>?)?.map((e) {
        if (e is Map) return (e['name'] ?? '').toString();
        return e.toString();
      }).where((s) => s.isNotEmpty).toList() ?? [],
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
      'imageUrl': imageUrl,
      'variants': variants,
      'addons': addons,
    };
  }
}

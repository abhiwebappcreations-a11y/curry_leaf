class MenuItem {
  final String id;
  final String name;
  final String category;
  final int pricePaise;
  final bool isVeg;
  final bool isAvailable;
  final String description;
  final String? imageUrl;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePaise,
    required this.isVeg,
    this.isAvailable = true,
    this.description = '',
    this.imageUrl,
  });

  double get priceRupees => pricePaise / 100.0;

  MenuItem copyWith({
    String? id,
    String? name,
    String? category,
    int? pricePaise,
    bool? isVeg,
    bool? isAvailable,
    String? description,
    String? imageUrl,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      pricePaise: pricePaise ?? this.pricePaise,
      isVeg: isVeg ?? this.isVeg,
      isAvailable: isAvailable ?? this.isAvailable,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      pricePaise: (json['pricePaise'] ?? json['pricePaiseSnapshot'] ?? 0) as int,
      isVeg: json['isVeg'] as bool? ?? true,
      isAvailable: json['isAvailable'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
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
    };
  }
}

class MenuItem {
  final String id;
  final String name;
  final String category;
  final int pricePaise;
  final bool isVeg;
  final bool isAvailable;
  final String description;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePaise,
    required this.isVeg,
    this.isAvailable = true,
    this.description = '',
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
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      pricePaise: pricePaise ?? this.pricePaise,
      isVeg: isVeg ?? this.isVeg,
      isAvailable: isAvailable ?? this.isAvailable,
      description: description ?? this.description,
    );
  }
}

import '../core/constants.dart';

class ItemVariant {
  final int id;
  final String size;
  final int quantity;
  final String? barcode;
  final double price;

  ItemVariant({
    required this.id,
    required this.size,
    required this.quantity,
    this.barcode,
    this.price = 0.0,
  });

  factory ItemVariant.fromJson(Map<String, dynamic> json) {
    return ItemVariant(
      id: json['id'] as int,
      size: (json['size'] as String?) ?? 'Única',
      quantity: json['quantity'] as int,
      barcode: json['barcode'] as String?,
      price: json['price'] != null ? double.parse(json['price'].toString()) : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size': size,
      'quantity': quantity,
      'barcode': barcode,
      'price': price,
    };
  }
}

class Item {
  final int id;
  final String name;
  final double price;
  final int quantity;
  final String type;
  final String? photoUrl;
  final String? barcode;
  final String size;
  final String gender;
  final List<ItemVariant> variants;

  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.type,
    this.photoUrl,
    this.barcode,
    this.size = 'Única',
    this.gender = 'Unisex',
    this.variants = const [],
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as int,
      name: json['name'] as String,
      price: double.parse(json['price'].toString()),
      quantity: json['quantity'] as int,
      type: (json['type'] as String?) ?? 'Otros',
      photoUrl: json['photo_url'] as String?,
      barcode: json['barcode'] as String?,
      size: (json['size'] as String?) ?? 'Única',
      gender: (json['gender'] as String?) ?? 'Unisex',
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => ItemVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'type': type,
      'photo_url': photoUrl,
      'barcode': barcode,
      'size': size,
      'gender': gender,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }

  // Returns the absolute URL to display the image on the client
  String? get fullPhotoUrl {
    if (photoUrl == null) return null;
    // If it's already an absolute URL (unlikely but safe check)
    if (photoUrl!.startsWith('http')) return photoUrl;
    return '${ApiConstants.mediaUrl}$photoUrl';
  }

  String get formattedPriceRange {
    if (variants.isEmpty) return '\$${price.toStringAsFixed(2)}';
    final prices = variants.map((v) => v.price).toSet().toList();
    if (prices.length == 1) return '\$${prices.first.toStringAsFixed(2)}';
    prices.sort();
    return '\$${prices.first.toStringAsFixed(2)} - \$${prices.last.toStringAsFixed(2)}';
  }

  @override
  String toString() => 'Item(id: $id, name: $name, price: $price, quantity: $quantity, type: $type, photoUrl: $photoUrl, variants: ${variants.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CartItem {
  final Item item;
  final ItemVariant variant;

  CartItem({
    required this.item,
    required this.variant,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          item.id == other.item.id &&
          variant.id == other.variant.id;

  @override
  int get hashCode => item.id.hashCode ^ variant.id.hashCode;

  @override
  String toString() => 'CartItem(item: ${item.name}, size: ${variant.size})';
}

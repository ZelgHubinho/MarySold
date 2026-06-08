import '../core/constants.dart';

class Item {
  final int id;
  final String name;
  final double price;
  final int quantity;
  final String type;
  final String? photoUrl;
  final String? barcode;

  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.type,
    this.photoUrl,
    this.barcode,
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
    };
  }

  // Returns the absolute URL to display the image on the client
  String? get fullPhotoUrl {
    if (photoUrl == null) return null;
    // If it's already an absolute URL (unlikely but safe check)
    if (photoUrl!.startsWith('http')) return photoUrl;
    return '${ApiConstants.mediaUrl}$photoUrl';
  }

  @override
  String toString() => 'Item(id: $id, name: $name, price: $price, quantity: $quantity, type: $type, photoUrl: $photoUrl)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

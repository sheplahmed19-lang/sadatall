import 'vendor.dart';
import 'attachment.dart';

class Order {
  final int id;
  final int userId;
  final int vendorId;
  final String status;
  final String description;
  final String? additionalNotes;
  final double price;
  final double? deliveryPrice;
  final String userAddress;
  final String phoneNumber;
  final int neighborhoodId;

  /// Minutes the vendor said it needs before the order is ready for pickup,
  /// set when the vendor accepts the order or sends a counter offer.
  final int? waitingTime;
  final bool isRated; // Added isRated field
  final User? user;
  final Vendor? vendor;
  final Neighborhood? neighborhood;
  final List<OrderItem>? orderItems;
  final Captain? captain;
  final List<Attachment>? attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.userId,
    required this.vendorId,
    required this.status,
    required this.description,
    this.additionalNotes,
    required this.price,
    this.deliveryPrice,
    required this.userAddress,
    required this.phoneNumber,
    required this.neighborhoodId,
    this.waitingTime,
    required this.isRated, // Added isRated field
    this.user,
    this.vendor,
    this.neighborhood,
    this.orderItems,
    this.captain,
    this.attachments,
    required this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['userId'] is num
          ? (json['userId'] as num).toInt()
          : int.tryParse(json['userId']?.toString() ?? '0') ?? 0,
      vendorId: json['vendorId'] is num
          ? (json['vendorId'] as num).toInt()
          : int.tryParse(json['vendorId']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      additionalNotes: json['additionalNotes']?.toString(),
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      deliveryPrice: json['deliveryPrice'] is num
          ? (json['deliveryPrice'] as num).toDouble()
          : json['deliveryPrice'] != null
              ? double.tryParse(json['deliveryPrice']?.toString() ?? '0') ?? 0.0
              : null,
      userAddress: json['userAddress']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      neighborhoodId: json['neighborhoodId'] is num
          ? (json['neighborhoodId'] as num).toInt()
          : int.tryParse(json['neighborhoodId']?.toString() ?? '0') ?? 0,
      waitingTime: json['waitingTime'] is num
          ? (json['waitingTime'] as num).toInt()
          : int.tryParse(json['waitingTime']?.toString() ?? ''),
      isRated: json['isRated'] as bool? ?? false, // Added isRated field
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      vendor: json['vendor'] != null
          ? Vendor.fromJson(json['vendor'] as Map<String, dynamic>)
          : null,
      neighborhood: json['neighborhood'] != null
          ? Neighborhood.fromJson(json['neighborhood'] as Map<String, dynamic>)
          : null,
      orderItems: json['orderItems'] != null
          ? (json['orderItems'] as List)
              .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      captain: json['captain'] != null
          ? Captain.fromJson(json['captain'] as Map<String, dynamic>)
          : null,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((item) => Attachment.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: DateTime.parse(
          json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'vendorId': vendorId,
      'status': status,
      'description': description,
      'additionalNotes': additionalNotes,
      'price': price,
      'deliveryPrice': deliveryPrice,
      'userAddress': userAddress,
      'phoneNumber': phoneNumber,
      'neighborhoodId': neighborhoodId,
      'waitingTime': waitingTime,
      'isRated': isRated, // Added isRated field
      'user': user?.toJson(),
      'vendor': vendor?.toJson(),
      'neighborhood': neighborhood?.toJson(),
      'orderItems': orderItems?.map((item) => item.toJson()).toList(),
      'captain': captain?.toJson(),
      'attachments': attachments?.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Order copyWith({
    int? id,
    int? userId,
    int? vendorId,
    String? status,
    String? description,
    String? additionalNotes,
    double? price,
    double? deliveryPrice,
    String? userAddress,
    String? phoneNumber,
    int? neighborhoodId,
    int? waitingTime,
    bool? isRated, // Added isRated field
    User? user,
    Vendor? vendor,
    Neighborhood? neighborhood,
    List<OrderItem>? orderItems,
    Captain? captain,
    List<Attachment>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vendorId: vendorId ?? this.vendorId,
      status: status ?? this.status,
      description: description ?? this.description,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      price: price ?? this.price,
      deliveryPrice: deliveryPrice ?? this.deliveryPrice,
      userAddress: userAddress ?? this.userAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      neighborhoodId: neighborhoodId ?? this.neighborhoodId,
      waitingTime: waitingTime ?? this.waitingTime,
      isRated: isRated ?? this.isRated, // Added isRated field
      user: user ?? this.user,
      vendor: vendor ?? this.vendor,
      neighborhood: neighborhood ?? this.neighborhood,
      orderItems: orderItems ?? this.orderItems,
      captain: captain ?? this.captain,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convenience getters for prices
  double? get totalPrice {
    if (price != 0 && deliveryPrice != null && deliveryPrice != 0) {
      return price + deliveryPrice!;
    }
    return null;
  }

  bool get hasBothPrices => price != 0 && deliveryPrice != null && deliveryPrice != 0;
  
  bool get hasAnyPrice => price > 0 || (deliveryPrice != null && deliveryPrice! > 0);

  // Convenience getters for captain location
  double? get captainLatitude => captain?.latitude;
  double? get captainLongitude => captain?.longitude;

  @override
  String toString() {
    return 'Order{id: $id, status: $status, price: $price, deliveryPrice: $deliveryPrice, userAddress: $userAddress}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class User {
  final int id;
  final String name;
  final String phone;

  User({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['userName']?.toString() ?? '',
      phone: json['phoneNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
    };
  }
}

class OrderVendor {
  final int id;
  final String vendorName;

  OrderVendor({
    required this.id,
    required this.vendorName,
  });

  factory OrderVendor.fromJson(Map<String, dynamic> json) {
    return OrderVendor(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      vendorName: json['vendorName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendorName': vendorName,
    };
  }
}

class Neighborhood {
  final int id;
  final String name;

  Neighborhood({
    required this.id,
    required this.name,
  });

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class OrderItem {
  final int id;
  final int menuId;
  final int quantity;
  final double price;
  final String? notes;
  final MenuItemInfo? menu;

  OrderItem({
    required this.id,
    required this.menuId,
    required this.quantity,
    required this.price,
    this.notes,
    this.menu,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      menuId: json['menuId'] is num
          ? (json['menuId'] as num).toInt()
          : int.tryParse(json['menuId']?.toString() ?? '0') ?? 0,
      quantity: json['quantity'] is num
          ? (json['quantity'] as num).toInt()
          : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString(),
      menu: json['menu'] != null
          ? MenuItemInfo.fromJson(json['menu'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menuId': menuId,
      'quantity': quantity,
      'price': price,
      'notes': notes,
      'menu': menu?.toJson(),
    };
  }
}

class MenuItemInfo {
  final int id;
  final String name;
  final String? photo;

  MenuItemInfo({
    required this.id,
    required this.name,
    this.photo,
  });

  factory MenuItemInfo.fromJson(Map<String, dynamic> json) {
    return MenuItemInfo(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      photo: json['photo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photo': photo,
    };
  }
}

class OrdersPagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  OrdersPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory OrdersPagination.fromJson(Map<String, dynamic> json) {
    return OrdersPagination(
      page: json['page'] is num
          ? (json['page'] as num).toInt()
          : int.tryParse(json['page']?.toString() ?? '1') ?? 1,
      limit: json['limit'] is num
          ? (json['limit'] as num).toInt()
          : int.tryParse(json['limit']?.toString() ?? '10') ?? 10,
      total: json['total'] is num
          ? (json['total'] as num).toInt()
          : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      pages: json['pages'] is num
          ? (json['pages'] as num).toInt()
          : int.tryParse(json['pages']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'pages': pages,
    };
  }
}

// Order status constants
class OrderStatus {
  static const String pending = 'PENDING';
  static const String counterOfferAccepted = 'COUNTER_OFFER_ACCEPTED';
  static const String acceptedByCaptain = 'ACCEPTED_BY_CAPTAIN';
  static const String delivered = 'DELIVERED';
  static const String cancelled = 'CANCELLED';

  static List<String> get allStatuses => [
        pending,
        counterOfferAccepted,
        acceptedByCaptain,
        delivered,
        cancelled,
      ];

  static String getStatusDisplayName(String status) {
    switch (status) {
      case pending:
        return 'في الانتظار';
      case counterOfferAccepted:
        return 'طلب مقبول';
      case acceptedByCaptain:
        return 'مقبول من الكابتن';
      case delivered:
        return 'تم التوصيل';
      case cancelled:
        return 'ملغي';
      default:
        return status;
    }
  }
}

class Captain {
  final String id;
  final String userName;
  final String phoneNumber;
  final double? latitude;
  final double? longitude;
  final int? ratingCount;
  final int? ratingSum;
  final String? photoUrl;

  Captain({
    required this.id,
    required this.userName,
    required this.phoneNumber,
    this.latitude,
    this.longitude,
    this.ratingCount,
    this.ratingSum,
    this.photoUrl,
  });

  double? get calculatedRating {
    if (ratingSum != null && ratingCount != null && ratingCount! > 0) {
      return ratingSum! / ratingCount!;
    }
    return null;
  }

  factory Captain.fromJson(Map<String, dynamic> json) {
    int? ratingSum = json['ratingSum'] is num ? (json['ratingSum'] as num).toInt() : null;
    int? ratingCount = json['ratingCount'] is num ? (json['ratingCount'] as num).toInt() : null;

    return Captain(
      id: json['id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      latitude:
          json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : null,
      ratingCount: ratingCount,
      ratingSum: ratingSum,
      photoUrl: json['photoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'phoneNumber': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
      'ratingCount': ratingCount,
      'ratingSum': ratingSum,
      'photoUrl': photoUrl,
    };
  }
}

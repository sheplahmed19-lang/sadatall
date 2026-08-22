import 'package:sadat_delivery_merged/vendor/models/vendor.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/time_utils.dart';
import 'attachment.dart';

class Order {
  final int id;
  final int userId;
  final int vendorId;
  final String status;
  final String description;
  final String? additionalNotes;
  final double? price;
  final double? deliveryPrice;
  final int? waitingTime;
  final String userAddress;
  final String phoneNumber;
  final int neighborhoodId;
  final User? user;
  final Vendor? vendor;
  final Neighborhood? neighborhood;
  final List<OrderItem>? orderItems;
  final Captain? captain;
  final List<Attachment>? attachments;
  final tz.TZDateTime createdAt;
  final tz.TZDateTime? updatedAt;

  Order({
    required this.id,
    required this.userId,
    required this.vendorId,
    required this.status,
    required this.description,
    this.additionalNotes,
    this.price,
    this.deliveryPrice,
    this.waitingTime,
    required this.userAddress,
    required this.phoneNumber,
    required this.neighborhoodId,
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
    // print('Parsing Order from JSON: $json'); // Debugging line
    final parsedPrice = json['price'] is num
        ? (json['price'] as num).toDouble()
        : double.tryParse(json['price']?.toString() ?? '');
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

      price: (parsedPrice != null && parsedPrice > 0)
          ? parsedPrice
          : parseEstimatedItemsPrice(json['description']?.toString() ?? ''),

      deliveryPrice: json['deliveryPrice'] is num
          ? (json['deliveryPrice'] as num).toDouble()
          : double.tryParse(json['deliveryPrice']?.toString() ?? '0') ?? 0.0,
      waitingTime: json['waitingTime'] is num
          ? (json['waitingTime'] as num).toInt()
          : int.tryParse(json['waitingTime']?.toString() ?? ''),
      userAddress: json['userAddress']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      neighborhoodId: json['neighborhoodId'] is num
          ? (json['neighborhoodId'] as num).toInt()
          : int.tryParse(json['neighborhoodId']?.toString() ?? '0') ?? 0,
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
                .map(
                  (item) => Attachment.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : null,
      createdAt: json['createdAt'] != null
          ? TimeUtils.toCairoTime(DateTime.parse(json['createdAt'].toString()))
          : TimeUtils.currentTimeInCairo,
      updatedAt: json['updatedAt'] != null
          ? TimeUtils.toCairoTime(DateTime.parse(json['updatedAt'].toString()))
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
      'waitingTime': waitingTime,
      'userAddress': userAddress,
      'phoneNumber': phoneNumber,
      'neighborhoodId': neighborhoodId,
      'user': user?.toJson(),
      'vendor': vendor?.toJson(),
      'neighborhood': neighborhood?.toJson(),
      'orderItems': orderItems?.map((item) => item.toJson()).toList(),
      'captain': captain?.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
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
    int? waitingTime,
    String? userAddress,
    String? phoneNumber,
    int? neighborhoodId,
    User? user,
    Vendor? vendor,
    Neighborhood? neighborhood,
    List<OrderItem>? orderItems,
    Captain? captain,
    tz.TZDateTime? createdAt,
    tz.TZDateTime? updatedAt,
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
      waitingTime: waitingTime ?? this.waitingTime,
      userAddress: userAddress ?? this.userAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      neighborhoodId: neighborhoodId ?? this.neighborhoodId,
      user: user ?? this.user,
      vendor: vendor ?? this.vendor,
      neighborhood: neighborhood ?? this.neighborhood,
      orderItems: orderItems ?? this.orderItems,
      captain: captain ?? this.captain,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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

  // Helper method to get the total price (price + deliveryPrice)
  // Returns null if either price or deliveryPrice is null or zero
  double? get totalPrice {
    if (price == null ||
        deliveryPrice == null ||
        price == 0 ||
        deliveryPrice == 0) {
      return null;
    }
    return price! + deliveryPrice!;
  }

  double? get estimatedItemsPriceFromDescription =>
      parseEstimatedItemsPrice(description);
  // Helper method to check if any price values are null or zero
  bool get hasNullPrices {
    return price == null ||
        deliveryPrice == null ||
        price == 0 ||
        deliveryPrice == 0;
  }

  // Orders placed from the user's cart embed the items total as text at the
  // end of the description (format: "...\n-----\nالإجمالي: 123 ج.م") since
  // there is no structured price on the order until the vendor sets one via
  // a counter offer / direct accept. Use this to show a meaningful price
  // instead of "0" while the order is still awaiting a vendor-set price.
  static double? parseEstimatedItemsPrice(String description) {
    if (description.isEmpty) return null;

    final lines = description.trim().split('\n');
    if (lines.isEmpty) return null;

    final lastLine = lines.last.trim();

    if (!lastLine.startsWith('الإجمالي:') || !lastLine.contains('ج.م')) {
      return null;
    }

    final priceString = lastLine
        .replaceAll('الإجمالي:', '')
        .replaceAll('ج.م', '')
        .trim();

    return double.tryParse(priceString);
  }

  // Best-effort display price: the vendor-set price if present, otherwise
  // the items total parsed from the description (see above), otherwise null.
  double? get displayPrice {
    if (price != null && price != 0) return price;

    return estimatedItemsPriceFromDescription;
  }

  // Text summary of the delivery route: from the vendor's neighborhood/address
  // to the order's destination neighborhood. Only meaningful when the order
  // has a real vendor (not a special order, vendorId == -1) and actually goes
  // somewhere — see [_isSameLocationDelivery].
  String? get routeLabel {
    if (vendorId == -1 || vendor == null) return null;
    if (_isSameLocationDelivery) return null;
    final vendorLocation = vendor!.neighborhoodName ?? vendor!.address;
    final destination = neighborhood?.name;
    if (destination == null) return null;
    return 'من $vendorLocation إلى $destination';
  }

  /// True when the order is delivered to the vendor's own location — a vendor
  /// ordering supplies for their own shop ("طلب شخصي للمتجر"), which sets the
  /// destination from the vendor's own profile.
  ///
  /// Nothing on the order marks it as a shop order (the flag never leaves the
  /// create-order screen), but it doesn't need to: "delivered where it
  /// started" is the same fact, already present in the data. Rendering it as
  /// a route produced a meaningless "من المعادي إلى المعادي".
  ///
  /// This model's Vendor carries only the neighborhood name, not its id, so
  /// the comparison is by name here (the captain app compares ids).
  bool get _isSameLocationDelivery {
    final vendorNeighborhood = vendor?.neighborhoodName;
    final destination = neighborhood?.name;
    return vendorNeighborhood != null &&
        destination != null &&
        vendorNeighborhood == destination;
  }
}

class User {
  final int id;
  final String name;
  final String phone;

  User({required this.id, required this.name, required this.phone});

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
    return {'id': id, 'name': name, 'phone': phone};
  }
}

class OrderVendor {
  final int id;
  final String vendorName;

  OrderVendor({required this.id, required this.vendorName});

  factory OrderVendor.fromJson(Map<String, dynamic> json) {
    return OrderVendor(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      vendorName: json['vendorName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'vendorName': vendorName};
  }
}

class Neighborhood {
  final int id;
  final String name;

  Neighborhood({required this.id, required this.name});

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
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
  final String? photoUrl;

  MenuItemInfo({required this.id, required this.name, this.photoUrl});

  factory MenuItemInfo.fromJson(Map<String, dynamic> json) {
    return MenuItemInfo(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'photoUrl': photoUrl};
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
    return {'page': page, 'limit': limit, 'total': total, 'pages': pages};
  }
}

// Order status constants
class OrderStatus {
  static const String pending = 'PENDING';
  static const String counterOfferSent = 'COUNTER_OFFER_SENT';
  static const String counterOfferAccepted = 'COUNTER_OFFER_ACCEPTED';
  static const String acceptedByCaptain = 'ACCEPTED_BY_CAPTAIN';
  static const String delivered = 'DELIVERED';
  static const String cancelled = 'CANCELLED';

  static List<String> get allStatuses => [
    pending,
    counterOfferSent,
    counterOfferAccepted,
    acceptedByCaptain,
    delivered,
    cancelled,
  ];

  static String getStatusDisplayName(String status) {
    switch (status) {
      case pending:
        return 'في الانتظار';
      case counterOfferSent:
        return 'عرض مرسل';
      case counterOfferAccepted:
        return 'عرض مقبول';
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
  final double? currentRating;
  final int? ratingCount;
  final String? photoUrl;

  Captain({
    required this.id,
    required this.userName,
    required this.phoneNumber,
    this.latitude,
    this.longitude,
    this.currentRating,
    this.ratingCount,
    this.photoUrl,
  });

  factory Captain.fromJson(Map<String, dynamic> json) {
    return Captain(
      id: json['id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : null,
      currentRating: json['currentRating'] is num
          ? (json['currentRating'] as num).toDouble()
          : null,
      ratingCount: json['ratingCount'] is num
          ? (json['ratingCount'] as num).toInt()
          : null,
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
      'currentRating': currentRating,
      'ratingCount': ratingCount,
      'photoUrl': photoUrl,
    };
  }
}

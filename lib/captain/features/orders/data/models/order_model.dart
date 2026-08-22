import 'package:json_annotation/json_annotation.dart';
import 'attachment_model.dart';

part 'order_model.g.dart';

@JsonSerializable()
class OrderModel {
  final String id;
  final String? userId;
  final String? captainId;
  final String? vendorId;
  final String neighborhoodId;
  @JsonKey(fromJson: _orderStatusFromJson, toJson: _orderStatusToJson)
  final OrderStatus status;
  final String description;
  final String? additionalNotes;
  final String userAddress;
  final double? userLongitude;
  final double? userLatitude;
  final String phoneNumber;
  final double? price;
  final double? deliveryPrice;
  final int? waitingTime;
  @JsonKey(fromJson: _dateTimeFromJsonRequired, toJson: _dateTimeToJsonRequired)
  final DateTime createdAt;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? counterOfferSentAt;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? acceptedByVend;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? acceptedByCapta;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? deliveredAt;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? finalizedAt;
  final UserInfo? user;
  final VendorInfo? vendor;
  final NeighborhoodInfo? neighborhood;
  final List<AttachmentModel>? attachments;

  OrderModel({
    required this.id,
    this.userId,
    this.captainId,
    this.vendorId,
    required this.neighborhoodId,
    required this.status,
    required this.description,
    this.additionalNotes,
    required this.userAddress,
    this.userLongitude,
    this.userLatitude,
    required this.phoneNumber,
    this.price,
    this.deliveryPrice,
    this.waitingTime,
    required this.createdAt,
    this.counterOfferSentAt,
    this.acceptedByVend,
    this.acceptedByCapta,
    this.deliveredAt,
    this.finalizedAt,
    this.user,
    this.vendor,
    this.neighborhood,
    this.attachments,
  });

  double get totalPrice => (price ?? 0) + (deliveryPrice ?? 0);

  String get vendorName {
    if (vendor != null) return vendor!.vendorName;
    if (vendorId == '-1') return 'طلب خاص';
    return 'غير محدد';
  }

  // Text summary of the delivery route: from the vendor's neighborhood/address
  // to the order's destination neighborhood. Only meaningful when the order
  // has a real vendor (not a special order, vendorId == '-1') and actually
  // goes somewhere — see [_isSameLocationDelivery].
  String? get routeLabel {
    if (vendorId == '-1' || vendor == null) return null;
    if (_isSameLocationDelivery) return null;
    final vendorLocation = vendor!.neighborhood?.name ?? vendor!.address;
    final destination = neighborhood?.name;
    if (destination == null) return null;
    return 'من $vendorLocation إلى $destination';
  }

  /// True when the order is delivered to the vendor's own location — a vendor
  /// ordering supplies for their own shop ("طلب شخصي للمتجر"), which sets the
  /// destination from the vendor's own profile.
  ///
  /// Nothing on the order marks it as a shop order (the flag never leaves the
  /// vendor app), but it doesn't need to: "delivered where it started" is the
  /// same fact, already present in the data. Rendering it as a route produced
  /// a meaningless "من المعادي إلى المعادي".
  ///
  /// Compares neighborhood ids when both are known, since two distinct
  /// neighborhoods can share a display name; falls back to names otherwise.
  bool get _isSameLocationDelivery {
    final vendorNeighborhoodId = vendor?.neighborhood?.id;
    final destinationId = neighborhood?.id;
    if (vendorNeighborhoodId != null && destinationId != null) {
      return vendorNeighborhoodId == destinationId;
    }

    final vendorName = vendor?.neighborhood?.name;
    final destinationName = neighborhood?.name;
    return vendorName != null &&
        destinationName != null &&
        vendorName == destinationName;
  }

  /// Name to show the captain for whoever receives this order.
  ///
  /// "Send package" orders are placed by one account on someone else's behalf
  /// and carry the real recipient in the notes as "الاسم: ...", so that wins
  /// over the account name — otherwise the captain would call the sender
  /// instead of the person waiting for the delivery.
  String get displayCustomerName {
    final notes = additionalNotes;
    if (notes != null) {
      final match = RegExp(r'الاسم:\s*(.+)').firstMatch(notes);
      final senderName = match?.group(1)?.trim();
      if (senderName != null && senderName.isNotEmpty) {
        return senderName;
      }
    }
    return user?.userName ?? 'غير محدد';
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrderModelToJson(this);

  static DateTime? _dateTimeFromJson(String? json) {
    return json != null ? DateTime.parse(json) : null;
  }

  static String? _dateTimeToJson(DateTime? dateTime) {
    return dateTime?.toIso8601String();
  }

  static DateTime _dateTimeFromJsonRequired(String json) {
    return DateTime.parse(json);
  }

  static String _dateTimeToJsonRequired(DateTime dateTime) {
    return dateTime.toIso8601String();
  }

  static OrderStatus _orderStatusFromJson(String json) {
    return OrderStatus.fromString(json);
  }

  static String _orderStatusToJson(OrderStatus status) {
    return status.value;
  }
}

@JsonSerializable()
class UserInfo {
  final String id;
  final String userName;
  final String? email;
  final String? address;
  final String phoneNumber;

  UserInfo({
    required this.id,
    required this.userName,
    this.email,
    this.address,
    required this.phoneNumber,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UserInfoToJson(this);
}

@JsonSerializable()
class VendorInfo {
  final String id;
  final String vendorName;
  final String contactNumber;
  final String address;
  final double? longitude;
  final double? latitude;
  final NeighborhoodInfo? neighborhood;

  VendorInfo({
    required this.id,
    required this.vendorName,
    required this.contactNumber,
    required this.address,
    this.longitude,
    this.latitude,
    this.neighborhood,
  });

  factory VendorInfo.fromJson(Map<String, dynamic> json) =>
      _$VendorInfoFromJson(json);
  Map<String, dynamic> toJson() => _$VendorInfoToJson(this);
}

@JsonSerializable()
class NeighborhoodInfo {
  final String id;
  final String name;

  NeighborhoodInfo({required this.id, required this.name});

  factory NeighborhoodInfo.fromJson(Map<String, dynamic> json) =>
      _$NeighborhoodInfoFromJson(json);
  Map<String, dynamic> toJson() => _$NeighborhoodInfoToJson(this);
}

enum OrderStatus {
  pending('PENDING'),
  counterOfferSent('COUNTER_OFFER_SENT'),
  counterOfferAccepted('COUNTER_OFFER_ACCEPTED'),
  acceptedByCaptain('ACCEPTED_BY_CAPTAIN'),
  delivered('DELIVERED'),
  cancelled('CANCELLED');

  const OrderStatus(this.value);
  final String value;

  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => OrderStatus.pending,
    );
  }
}

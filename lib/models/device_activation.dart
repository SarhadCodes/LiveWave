import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-selectable subscription length for a device.
enum ActivationPlan {
  hours24('24h', '24 Hours', Duration(hours: 24)),
  month1('1month', '1 Month', Duration(days: 30)),
  months5('5months', '5 Months', Duration(days: 150)),
  year1('1year', '1 Year', Duration(days: 365));

  const ActivationPlan(this.id, this.label, this.duration);

  final String id;
  final String label;
  final Duration duration;

  static ActivationPlan? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final plan in ActivationPlan.values) {
      if (plan.id == id) return plan;
    }
    return null;
  }
}

class DeviceActivation {
  final String id;
  final String macAddress;
  final String m3uUrl;
  final String plan;
  final String status;
  final bool isActive;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final String? label;
  final String? platform;

  const DeviceActivation({
    required this.id,
    required this.macAddress,
    this.m3uUrl = '',
    this.plan = '',
    this.status = 'pending',
    this.isActive = false,
    this.activatedAt,
    this.expiresAt,
    this.lastSeenAt,
    this.createdAt,
    this.label,
    this.platform,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isUsable =>
      isActive &&
      status == 'active' &&
      !isExpired &&
      m3uUrl.trim().isNotEmpty;

  ActivationPlan? get planEnum => ActivationPlan.fromId(plan);

  factory DeviceActivation.fromFirestore(Map<String, dynamic> data, String id) {
    return DeviceActivation(
      id: id,
      macAddress: (data['macAddress'] ?? '').toString(),
      m3uUrl: (data['m3uUrl'] ?? '').toString(),
      plan: (data['plan'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      isActive: data['isActive'] == true,
      activatedAt: _toDateTime(data['activatedAt']),
      expiresAt: _toDateTime(data['expiresAt']),
      lastSeenAt: _toDateTime(data['lastSeenAt']),
      createdAt: _toDateTime(data['createdAt']),
      label: data['label']?.toString(),
      platform: data['platform']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'macAddress': macAddress,
      'm3uUrl': m3uUrl,
      'plan': plan,
      'status': status,
      'isActive': isActive,
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (lastSeenAt != null) 'lastSeenAt': Timestamp.fromDate(lastSeenAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (label != null) 'label': label,
      if (platform != null) 'platform': platform,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

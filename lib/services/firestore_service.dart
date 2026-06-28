import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/channel.dart';
import '../models/ad.dart';
import '../models/device_activation.dart';
import 'device_service.dart';

class FirestoreService {
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      throw Exception('FIREBASE_NOT_INITIALIZED');
    }
  }

  static const String _channelsCollection = 'channels';
  static const String _adsCollection = 'ads';
  static const String _movieOverrides = 'movie_overrides';
  static const String _tvOverrides = 'tv_overrides';
  static const String _deviceActivations = 'device_activations';

  // Get active channels as a stream for real-time updates
  Stream<List<Channel>> getActiveChannelsStream() {
    try {
      return _firestore
          .collection(_channelsCollection)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        final channels = snapshot.docs
            .map((doc) => Channel.fromFirestore(doc.data(), doc.id))
            .toList();
        channels.sort((a, b) => a.order.compareTo(b.order));
        return channels;
      });
    } catch (e) {
      debugPrint('Firestore Stream Error: $e');
      return Stream.value([]);
    }
  }

  // Get active channels as a one-time fetch
  Future<List<Channel>> getActiveChannels() async {
    try {
      final querySnapshot = await _firestore
          .collection(_channelsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final channels = querySnapshot.docs
          .map((doc) => Channel.fromFirestore(doc.data(), doc.id))
          .toList();
      channels.sort((a, b) => a.order.compareTo(b.order));
      return channels;
    } catch (e) {
      debugPrint('Firestore Fetch Error: $e');
      return [];
    }
  }

  // Get channels by category
  Future<List<Channel>> getChannelsByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection(_channelsCollection)
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .get();

      final channels = querySnapshot.docs
          .map((doc) => Channel.fromFirestore(doc.data(), doc.id))
          .toList();
      channels.sort((a, b) => a.order.compareTo(b.order));
      return channels;
    } catch (e) {
      debugPrint('Firestore Category Fetch Error: $e');
      return [];
    }
  }

  // Get all unique categories
  Future<List<String>> getCategories() async {
    try {
      final querySnapshot = await _firestore
          .collection(_channelsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final categories = querySnapshot.docs
          .map((doc) => doc.data()['category'] as String?)
          .where((category) => category != null)
          .cast<String>()
          .toSet()
          .toList();

      categories.sort();
      return categories;
    } catch (e) {
      debugPrint('Firestore Categories Error: $e');
      return [];
    }
  }

  // Get a single channel by ID
  Future<Channel?> getChannelById(String channelId) async {
    try {
      final doc = await _firestore
          .collection(_channelsCollection)
          .doc(channelId)
          .get();

      if (doc.exists && doc.data() != null) {
        return Channel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Firestore Channel ID Error: $e');
      return null;
    }
  }

  // ============ AD METHODS ============

  // Get active ads as a stream for real-time updates
  Stream<List<Ad>> getActiveAdsStream() {
    try {
      return _firestore
          .collection(_adsCollection)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        final ads = snapshot.docs
            .map((doc) => Ad.fromFirestore(doc.data(), doc.id))
            .toList();
        ads.sort((a, b) => a.order.compareTo(b.order));
        return ads;
      });
    } catch (e) {
      debugPrint('Ads Stream Error: $e');
      return Stream.value([]);
    }
  }

  // Get active ads as a one-time fetch
  Future<List<Ad>> getActiveAds() async {
    try {
      final querySnapshot = await _firestore
          .collection(_adsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final ads = querySnapshot.docs
          .map((doc) => Ad.fromFirestore(doc.data(), doc.id))
          .toList();
      ads.sort((a, b) => a.order.compareTo(b.order));
      return ads;
    } catch (e) {
      debugPrint('Firestore Ads Fetch Error: $e');
      return [];
    }
  }

  // ============ MEDIA OVERRIDE METHODS ============

  /// Get manual link overrides from Firestore by querying the 'tmdbId' field.
  Future<Map<String, dynamic>?> getMediaOverride(int tmdbId, {required bool isMovie}) async {
    try {
      final collection = isMovie ? _movieOverrides : _tvOverrides;
      debugPrint('[FirestoreService] Querying $collection for tmdbId: $tmdbId');
      
      final querySnapshot = await _firestore
          .collection(collection)
          .where('tmdbId', isEqualTo: tmdbId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
    } catch (e) {
      debugPrint('Firestore Override Error: $e');
    }
    return null;
  }

  // ============ ADMIN CRUD METHODS ============

  Future<void> saveMediaOverride(int tmdbId, Map<String, dynamic> data, {required bool isMovie}) async {
    try {
      final collection = isMovie ? _movieOverrides : _tvOverrides;
      
      // Ensure the tmdbId field is included in the data
      data['tmdbId'] = tmdbId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      // We search for an existing doc with this tmdbId first to update it, 
      // or create a new one with a descriptive ID if it doesn't exist.
      final querySnapshot = await _firestore
          .collection(collection)
          .where('tmdbId', isEqualTo: tmdbId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing
        await querySnapshot.docs.first.reference.update(data);
      } else {
        // Create new
        // We use a descriptive ID for the document
        String label = data['title'] ?? (isMovie ? 'Movie' : 'TV');
        String docId = '${label.replaceAll(' ', '_')}_$tmdbId';
        await _firestore.collection(collection).doc(docId).set(data);
      }
    } catch (e) {
      debugPrint('Firestore Save Error: $e');
      rethrow;
    }
  }

  /// Delete a media override
  Future<void> deleteMediaOverride(int tmdbId, {required bool isMovie}) async {
    try {
      final collection = isMovie ? _movieOverrides : _tvOverrides;
      
      final querySnapshot = await _firestore
          .collection(collection)
          .where('tmdbId', isEqualTo: tmdbId)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Firestore Delete Error: $e');
      rethrow;
    }
  }

  /// Get all overrides for listing in Admin Panel
  Future<List<Map<String, dynamic>>> getAllOverrides({required bool isMovie}) async {
    try {
      final collection = isMovie ? _movieOverrides : _tvOverrides;
      final snapshot = await _firestore.collection(collection).orderBy('updatedAt', descending: true).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Firestore Get All Error: $e');
      return [];
    }
  }

  // ============ CHANNEL ADMIN CRUD METHODS ============

  /// Save or Update a live channel. Returns true on success.
  Future<bool> saveChannel(Map<String, dynamic> data, {String? existingId}) async {
    try {
      // Remove docId from the data — it's our local key, not a Firestore field
      final writeData = Map<String, dynamic>.from(data);
      writeData.remove('docId');
      writeData['updatedAt'] = FieldValue.serverTimestamp();

      if (existingId != null) {
        await _firestore.collection(_channelsCollection).doc(existingId).update(writeData);
      } else {
        final docId = '${(writeData['name'] ?? 'channel').toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
        await _firestore.collection(_channelsCollection).doc(docId).set(writeData);
      }
      return true;
    } catch (e) {
      debugPrint('Firestore Channel Save Error: $e');
      return false;
    }
  }

  /// Delete a live channel by its document ID. Returns true on success.
  Future<bool> deleteChannel(String docId) async {
    try {
      await _firestore.collection(_channelsCollection).doc(docId).delete();
      return true;
    } catch (e) {
      debugPrint('Firestore Channel Delete Error: $e');
      return false;
    }
  }

  /// Get all live channels for Admin Panel (no active filter, shows everything)
  Future<List<Map<String, dynamic>>> getAllChannels() async {
    try {
      final snapshot = await _firestore
          .collection(_channelsCollection)
          .get(); // No filter — show ALL channels in admin
      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
      // Sort by order field if present, then by name
      docs.sort((a, b) {
        final aOrder = (a['order'] as num?)?.toInt() ?? 9999;
        final bOrder = (b['order'] as num?)?.toInt() ?? 9999;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      });
      return docs;
    } catch (e) {
      debugPrint('Firestore Get Channels Error: $e');
      return [];
    }
  }

  // ============ DEVICE ACTIVATION METHODS ============

  String _deviceDocId(String mac) => DeviceService.macToDocId(mac);

  /// Called on every app launch — creates a pending record if the device is new.
  Future<void> registerDeviceSeen(String mac, {String? platform}) async {
    try {
      final docId = _deviceDocId(mac);
      final ref = _firestore.collection(_deviceActivations).doc(docId);
      final snap = await ref.get();
      final displayMac = DeviceService.formatDisplayMac(mac);

      if (!snap.exists) {
        await ref.set({
          'macAddress': displayMac,
          'status': 'pending',
          'isActive': false,
          'plan': '',
          'm3uUrl': '',
          'platform': platform ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.update({
          'macAddress': displayMac,
          'lastSeenAt': FieldValue.serverTimestamp(),
          if (platform != null && platform.isNotEmpty) 'platform': platform,
        });
      }
    } catch (e) {
      debugPrint('Firestore registerDeviceSeen Error: $e');
    }
  }

  Future<DeviceActivation?> getDeviceActivation(String mac) async {
    try {
      final doc = await _firestore
          .collection(_deviceActivations)
          .doc(_deviceDocId(mac))
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return DeviceActivation.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Firestore getDeviceActivation Error: $e');
      return null;
    }
  }

  Future<List<DeviceActivation>> getAllDeviceActivations() async {
    try {
      final snapshot = await _firestore
          .collection(_deviceActivations)
          .orderBy('lastSeenAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => DeviceActivation.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Firestore getAllDeviceActivations Error: $e');
      try {
        final snapshot =
            await _firestore.collection(_deviceActivations).get();
        final list = snapshot.docs
            .map((doc) => DeviceActivation.fromFirestore(doc.data(), doc.id))
            .toList();
        list.sort((a, b) {
          final aTime = a.lastSeenAt ?? a.createdAt ?? DateTime(1970);
          final bTime = b.lastSeenAt ?? b.createdAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
        return list;
      } catch (e2) {
        debugPrint('Firestore getAllDeviceActivations fallback Error: $e2');
        return [];
      }
    }
  }

  Future<void> activateDevice({
    required String mac,
    required String m3uUrl,
    required ActivationPlan plan,
    String? label,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(plan.duration);
    final docId = _deviceDocId(mac);
    await _firestore.collection(_deviceActivations).doc(docId).set({
      'macAddress': DeviceService.formatDisplayMac(mac),
      'm3uUrl': m3uUrl.trim(),
      'plan': plan.id,
      'status': 'active',
      'isActive': true,
      'activatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'lastSeenAt': FieldValue.serverTimestamp(),
      if (label != null && label.isNotEmpty) 'label': label,
    }, SetOptions(merge: true));
  }

  Future<void> extendDevicePlan({
    required String mac,
    required ActivationPlan plan,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(plan.duration);
    await _firestore.collection(_deviceActivations).doc(_deviceDocId(mac)).set({
      'plan': plan.id,
      'status': 'active',
      'isActive': true,
      'activatedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
    }, SetOptions(merge: true));
  }

  Future<void> updateDeviceM3u(String mac, String m3uUrl) async {
    await _firestore.collection(_deviceActivations).doc(_deviceDocId(mac)).set({
      'm3uUrl': m3uUrl.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> markDeviceExpired(String mac) async {
    await _firestore.collection(_deviceActivations).doc(_deviceDocId(mac)).set({
      'status': 'expired',
      'isActive': false,
    }, SetOptions(merge: true));
  }

  Future<void> deactivateDevice(String mac) async {
    await _firestore.collection(_deviceActivations).doc(_deviceDocId(mac)).set({
      'status': 'pending',
      'isActive': false,
      'm3uUrl': '',
      'plan': '',
      'expiresAt': FieldValue.delete(),
      'activatedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteDeviceActivation(String docId) async {
    await _firestore.collection(_deviceActivations).doc(docId).delete();
  }
}

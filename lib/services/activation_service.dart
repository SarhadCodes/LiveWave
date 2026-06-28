import 'package:flutter/foundation.dart';

import '../config/xtream_config.dart';
import '../providers/settings_provider.dart';
import 'device_service.dart';
import 'firestore_service.dart';

enum ActivationStatus { pending, active, expired, error }

class ActivationResult {
  final ActivationStatus status;
  final String macAddress;
  final DateTime? expiresAt;
  final String? planLabel;
  final String? message;

  const ActivationResult({
    required this.status,
    required this.macAddress,
    this.expiresAt,
    this.planLabel,
    this.message,
  });
}

/// Registers the device, checks Firestore activation, and applies content source.
class ActivationService {
  final FirestoreService _firestore;

  ActivationService({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  Future<ActivationResult> resolve(
    SettingsProvider settings, {
    String? deviceId,
  }) async {
    var displayMac = deviceId?.trim() ?? '';
    try {
      if (displayMac.isEmpty) {
        final mac = await DeviceService.getMacAddress();
        displayMac = DeviceService.formatDisplayMac(mac);
      }

      await _firestore.registerDeviceSeen(
        displayMac,
        platform: defaultTargetPlatform.name,
      );

      final activation = await _firestore.getDeviceActivation(displayMac);

      if (activation == null || activation.status == 'pending') {
        await _applyDefaultCatalog(settings);
        return ActivationResult(
          status: ActivationStatus.pending,
          macAddress: displayMac,
          message: 'Waiting for admin activation',
        );
      }

      if (activation.isExpired ||
          activation.status == 'expired' ||
          !activation.isUsable) {
        if (activation.status != 'expired') {
          await _firestore.markDeviceExpired(displayMac);
        }
        await _applyDefaultCatalog(settings);
        return ActivationResult(
          status: ActivationStatus.expired,
          macAddress: displayMac,
          expiresAt: activation.expiresAt,
          planLabel: activation.planEnum?.label,
          message: 'Subscription expired — showing default channels',
        );
      }

      await _applyM3uActivation(settings, activation.m3uUrl);
      return ActivationResult(
        status: ActivationStatus.active,
        macAddress: displayMac,
        expiresAt: activation.expiresAt,
        planLabel: activation.planEnum?.label,
      );
    } catch (e) {
      debugPrint('[ActivationService] resolve failed: $e');
      if (displayMac.isEmpty) {
        try {
          final mac = await DeviceService.getMacAddress();
          displayMac = DeviceService.formatDisplayMac(mac);
        } catch (_) {}
      }
      await _applyDefaultCatalog(settings);
      return ActivationResult(
        status: ActivationStatus.error,
        macAddress: displayMac,
        message: e.toString(),
      );
    }
  }

  Future<void> _applyM3uActivation(
    SettingsProvider settings,
    String m3uUrl,
  ) async {
    final creds = XtreamConfig.normalize(
      XtreamCredentials(
        serverUrl: '',
        username: '',
        password: '',
        m3uUrl: m3uUrl,
      ),
    );
    await XtreamConfig.save(creds);
    await settings.setActivationManaged(true);
    await settings.setContentSource(SettingsProvider.contentSourceXtream);
  }

  Future<void> _applyDefaultCatalog(SettingsProvider settings) async {
    await XtreamConfig.clearActivationM3u();
    await settings.setActivationManaged(true);
    await settings.setContentSource(SettingsProvider.contentSourceFirestore);
  }
}

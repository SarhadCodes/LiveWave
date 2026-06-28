import 'package:flutter/foundation.dart';

import '../services/activation_service.dart';
import '../services/device_service.dart';
import 'settings_provider.dart';

class ActivationProvider with ChangeNotifier {
  final ActivationService _service;

  ActivationProvider({ActivationService? service})
      : _service = service ?? ActivationService() {
    _loadMacAddress();
  }

  ActivationStatus _status = ActivationStatus.pending;
  String _macAddress = '';
  DateTime? _expiresAt;
  String? _message;
  String? _planLabel;
  bool _resolved = false;
  bool _macLoading = true;

  ActivationStatus get status => _status;
  String get macAddress => _macAddress;
  DateTime? get expiresAt => _expiresAt;
  String? get message => _message;
  String? get planLabel => _planLabel;
  bool get isResolved => _resolved;
  bool get isMacLoading => _macLoading;
  bool get isPending => _status == ActivationStatus.pending;
  bool get isActive => _status == ActivationStatus.active;
  bool get isExpired => _status == ActivationStatus.expired;
  bool get isError => _status == ActivationStatus.error;

  /// Loads device MAC/ID immediately — does not wait for Firestore.
  Future<void> _loadMacAddress() async {
    if (_macAddress.isNotEmpty) {
      _macLoading = false;
      return;
    }
    _macLoading = true;
    notifyListeners();
    try {
      final mac = await DeviceService.getMacAddress();
      _macAddress = DeviceService.formatDisplayMac(mac);
    } catch (e) {
      debugPrint('[ActivationProvider] MAC load failed: $e');
      _macAddress = 'Unavailable';
    } finally {
      _macLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureMacAddress() => _loadMacAddress();

  Future<void> resolve(SettingsProvider settings) async {
    await _loadMacAddress();
    final result = await _service.resolve(
      settings,
      deviceId: _macAddress,
    );
    _status = result.status;
    if (result.macAddress.isNotEmpty) {
      _macAddress = result.macAddress;
    }
    _expiresAt = result.expiresAt;
    _planLabel = result.planLabel;
    _message = result.message;
    _resolved = true;
    _macLoading = false;
    notifyListeners();
  }

  Future<void> recheck(SettingsProvider settings) async {
    await resolve(settings);
  }
}

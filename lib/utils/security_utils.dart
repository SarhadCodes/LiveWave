import 'dart:io';
import 'package:flutter/foundation.dart';

class SecurityUtils {
  /// Checks if a VPN or Proxy is likely active.
  /// This scans network interfaces for common VPN/Tunnel names
  /// and checks for system proxy settings.
  static Future<bool> isVpnOrProxyActive() async {
    // 1. Check Network Interfaces
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      
      final vpnKeywords = ['tun', 'tap', 'ppp', 'ipsec', 'vpn', 'utun', 'wireguard'];
      
      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        for (var keyword in vpnKeywords) {
          if (name.contains(keyword)) {
            debugPrint('VPN Detected via interface: ${interface.name}');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking network interfaces: $e');
    }

    // 2. Check for Proxy Settings
    try {
      String? proxy = Platform.environment['http_proxy'] ?? 
                      Platform.environment['HTTP_PROXY'] ??
                      Platform.environment['https_proxy'] ??
                      Platform.environment['HTTPS_PROXY'];
      
      if (proxy != null && proxy.isNotEmpty) {
        debugPrint('Proxy Detected via environment: $proxy');
        return true;
      }
    } catch (e) {
      debugPrint('Error checking proxy environment: $e');
    }

    return false;
  }
}

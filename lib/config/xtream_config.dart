import 'package:shared_preferences/shared_preferences.dart';

/// Default test credentials — overridden when user saves values in Settings.
class XtreamConfig {
  static const String defaultServerUrl = 'http://forevertv.me:2095';
  static const String defaultUsername = 'awfpP2FMIS2EMo';
  static const String defaultPassword = 'kxSnMClWtvccvh';
  static const String _legacyWrongPassword = 'kxSnMClWtvccvhr';

  /// SharedPreferences keys (NOT the credential values themselves).
  static const String keyServerUrl = 'xtream_server_url';
  static const String keyUsername = 'xtream_username';
  static const String keyPassword = 'xtream_password';
  static const String keyM3uUrl = 'xtream_m3u_url';

  static XtreamCredentials? _cached;

  static void clearCache() => _cached = null;

  static Future<XtreamCredentials> load() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var password = (prefs.getString(keyPassword) ?? defaultPassword).trim();
    if (password == _legacyWrongPassword) {
      password = defaultPassword;
      await prefs.setString(keyPassword, password);
    }
    _cached = XtreamCredentials(
      serverUrl: _clean(prefs.getString(keyServerUrl) ?? defaultServerUrl),
      username: _clean(prefs.getString(keyUsername) ?? defaultUsername),
      password: password,
      m3uUrl: _clean(prefs.getString(keyM3uUrl) ?? ''),
    );
    _cached = normalize(_cached!);
    return _cached!;
  }

  /// Writes default server/user/password to storage when nothing saved yet.
  static Future<void> ensureDefaultsSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(keyServerUrl)) {
      await prefs.setString(keyServerUrl, defaultServerUrl);
    }
    if (!prefs.containsKey(keyUsername)) {
      await prefs.setString(keyUsername, defaultUsername);
    }
    if (!prefs.containsKey(keyPassword)) {
      await prefs.setString(keyPassword, defaultPassword);
    } else if (prefs.getString(keyPassword) == _legacyWrongPassword) {
      await prefs.setString(keyPassword, defaultPassword);
    }
    clearCache();
  }

  static XtreamCredentials get defaults => const XtreamCredentials(
        serverUrl: defaultServerUrl,
        username: defaultUsername,
        password: defaultPassword,
      );

  static Future<void> save(XtreamCredentials credentials) async {
    final normalized = normalize(credentials);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyServerUrl, _clean(normalized.serverUrl));
    await prefs.setString(keyUsername, _clean(normalized.username));
    await prefs.setString(keyPassword, normalized.password.trim());
    await prefs.setString(keyM3uUrl, _clean(normalized.m3uUrl));
    clearCache();
  }

  /// Clears admin-assigned M3U when activation expires.
  static Future<void> clearActivationM3u() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyM3uUrl);
    clearCache();
  }

  static String _clean(String value) => value.trim().replaceAll(RegExp(r'/+$'), '');

  /// Accepts `http://host:port`, or a full get.php / player_api URL pasted by mistake.
  static XtreamCredentials normalize(XtreamCredentials credentials) {
    var serverUrl = credentials.serverUrl.trim();
    var username = credentials.username.trim();
    var password = credentials.password.trim();
    var m3uUrl = credentials.m3uUrl.trim();

    if (serverUrl.isNotEmpty &&
        !serverUrl.startsWith('http://') &&
        !serverUrl.startsWith('https://')) {
      serverUrl = 'http://$serverUrl';
    }
    if (m3uUrl.isNotEmpty &&
        !m3uUrl.startsWith('http://') &&
        !m3uUrl.startsWith('https://')) {
      m3uUrl = 'http://$m3uUrl';
    }

    final uri = Uri.tryParse(serverUrl);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      if (serverUrl.contains('get.php')) {
        m3uUrl = m3uUrl.isEmpty ? serverUrl : m3uUrl;
        if (username.isEmpty) username = uri.queryParameters['username'] ?? username;
        if (password.isEmpty) password = uri.queryParameters['password'] ?? password;
      }
      serverUrl = _originFromUri(uri);
    }

    if (m3uUrl.isNotEmpty) {
      final m3uUri = Uri.tryParse(m3uUrl);
      if (m3uUri != null && m3uUri.hasScheme && m3uUri.host.isNotEmpty) {
        if (m3uUrl.contains('get.php')) {
          if (username.isEmpty) {
            username = m3uUri.queryParameters['username'] ?? username;
          }
          if (password.isEmpty) {
            password = m3uUri.queryParameters['password'] ?? password;
          }
          if (serverUrl.isEmpty) serverUrl = _originFromUri(m3uUri);
        }
      }
    }

    return XtreamCredentials(
      serverUrl: serverUrl,
      username: username,
      password: password,
      m3uUrl: m3uUrl,
    );
  }

  static String _originFromUri(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }
}

class XtreamCredentials {
  final String serverUrl;
  final String username;
  final String password;
  /// Full M3U URL copied from IPTV Smarters, TiviMate, etc.
  final String m3uUrl;

  const XtreamCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.m3uUrl = '',
  });

  String get baseUrl {
    final url = serverUrl.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  XtreamCredentials withBaseUrl(String base) => XtreamCredentials(
        serverUrl: base,
        username: username,
        password: password,
        m3uUrl: m3uUrl,
      );

  bool get hasM3uUrl => m3uUrl.trim().isNotEmpty;

  bool get hasApiCredentials =>
      serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  bool get isComplete => hasM3uUrl || hasApiCredentials;

  /// Standard Xtream M3U URL built from server + login (same as XP Player).
  Uri get builtM3uUri => Uri.parse('$baseUrl/get.php').replace(
        queryParameters: {
          'username': username,
          'password': password,
          'type': 'm3u_plus',
        },
      );
}

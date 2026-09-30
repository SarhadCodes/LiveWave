import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/xtream_config.dart';
import '../providers/settings_provider.dart';
import '../providers/channels_provider.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';
import '../providers/activation_provider.dart';
import '../services/update_service.dart';
import '../services/xtream_service.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import 'admin/admin_login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'account_screen.dart';
import 'downloads_screen.dart';
import 'category_order_screen.dart';
import '../widgets/tv_settings_layout.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _adminTaps = 0;
  int _devTaps = 0;
  final _authService = AuthService();
  final _xtreamServerController = TextEditingController();
  final _xtreamUserController = TextEditingController();
  final _xtreamPassController = TextEditingController();
  bool _xtreamCredsLoaded = false;
  String? _selectedTvSettingId = 'account';

  @override
  void initState() {
    super.initState();
    _loadXtreamCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActivationReady());
  }

  Future<void> _ensureActivationReady() async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.ensureLoaded();
    final activation = Provider.of<ActivationProvider>(context, listen: false);
    await activation.ensureMacAddress();
    if (!activation.isResolved) {
      await activation.resolve(settings);
    }
  }

  @override
  void dispose() {
    _xtreamServerController.dispose();
    _xtreamUserController.dispose();
    _xtreamPassController.dispose();
    super.dispose();
  }

  Future<void> _loadXtreamCredentials() async {
    await XtreamConfig.ensureDefaultsSaved();
    final creds = await XtreamConfig.load();
    if (!mounted) return;
    setState(() {
      _xtreamServerController.text = creds.serverUrl;
      _xtreamUserController.text = creds.username;
      _xtreamPassController.text = creds.password;
      _xtreamCredsLoaded = true;
    });
  }

  void _handleDeveloperUnlock() {
    _devTaps++;
    if (_devTaps >= 5) {
      _devTaps = 0;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      settings.setDeveloperModeEnabled(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer mode enabled'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleAdminAccess() async {
    _adminTaps++;
    if (_adminTaps >= 7) {
      _adminTaps = 0;
      
      // Check if already logged in
      if (_authService.isAdmin()) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
      } else {
        final loggedIn = await Navigator.push<bool>(
          context, 
          MaterialPageRoute(builder: (context) => const AdminLoginScreen())
        );
        if (loggedIn == true && mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final l10n = AppLocalizations.of(context);
    final isMobile = settings.layoutMode == 'mobile';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: isMobile
          ? _buildMobileSettingsBody(settings, l10n, isMobile)
          : _buildTvSettingsBody(settings, l10n),
    );
  }

  Widget _buildMobileSettingsBody(
    SettingsProvider settings,
    AppLocalizations l10n,
    bool isMobile,
  ) {
    final horizontalPadding = AppTheme.spacingM;

    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  blurRadius: 100,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: AppTheme.spacingM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildModernHeader(isMobile, l10n),
              const SizedBox(height: 20),
              if (settings.activationManaged) ...[
                _buildAccountSection(isMobile),
                const SizedBox(height: 20),
              ],
              _buildLanguageSection(settings, isMobile, l10n),
              const SizedBox(height: 20),
              if (!settings.activationManaged) ...[
                _buildContentSourceSection(settings, isMobile, l10n),
                const SizedBox(height: 20),
                _buildXtreamCredentialsSection(settings, isMobile, l10n),
                const SizedBox(height: 20),
              ],
              _buildUserInterfaceSection(settings, isMobile, l10n),
              const SizedBox(height: 20),
              _buildCategoryOrderSection(isMobile, l10n),
              const SizedBox(height: 20),
              _buildDownloadsSection(isMobile, l10n),
              const SizedBox(height: 20),
              _buildUpdateSection(isMobile, l10n),
              const SizedBox(height: 40),
              _buildFooter(l10n),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTvSettingsBody(SettingsProvider settings, AppLocalizations l10n) {
    return Consumer<ActivationProvider>(
      builder: (context, activation, _) {
        final entries = _buildTvSettingsEntries(settings, activation, l10n);
        final selectedId = _selectedTvSettingId != null &&
                entries.any((e) => e.id == _selectedTvSettingId)
            ? _selectedTvSettingId!
            : (entries.isNotEmpty ? entries.first.id : null);
        final initialFocusId = settings.activationManaged &&
                entries.any((e) => e.id == 'account')
            ? 'account'
            : selectedId;

        return TvSettingsLayout(
          title: l10n.translate('settings'),
          entries: entries,
          selectedId: selectedId,
          initialFocusId: initialFocusId,
          onSelected: (id) {
            if (_selectedTvSettingId != id) {
              setState(() => _selectedTvSettingId = id);
            }
          },
          detailBuilder: (id) => _buildTvSettingDetail(id, settings, l10n, activation),
          footer: _buildFooter(l10n),
        );
      },
    );
  }

  List<TvSettingsEntry> _buildTvSettingsEntries(
    SettingsProvider settings,
    ActivationProvider activation,
    AppLocalizations l10n,
  ) {
    final entries = <TvSettingsEntry>[];

    if (settings.activationManaged) {
      final accountSubtitle = activation.isActive
          ? (activation.expiresAt != null
              ? 'Active • expires ${_formatShortDate(activation.expiresAt!)}'
              : 'Subscription active')
          : activation.isExpired
              ? 'Subscription expired'
              : 'Device activation';
      entries.add(TvSettingsEntry(
        id: 'account',
        section: 'Account',
        title: 'My Account',
        subtitle: accountSubtitle,
        icon: Icons.person_rounded,
      ));
    }

    entries.addAll([
      TvSettingsEntry(
        id: 'language',
        section: 'General',
        title: l10n.translate('language'),
        subtitle: settings.language == 'ku'
            ? l10n.translate('kurdish')
            : l10n.translate('english'),
        icon: Icons.language_rounded,
      ),
      TvSettingsEntry(
        id: 'layout',
        section: 'General',
        title: l10n.translate('user_interface'),
        subtitle: settings.layoutMode == 'tv'
            ? l10n.translate('cinema_tv')
            : l10n.translate('pocket_mobile'),
        icon: Icons.grid_view_rounded,
      ),
      TvSettingsEntry(
        id: 'category_order',
        section: 'General',
        title: l10n.translate('category_order'),
        subtitle: l10n.translate('category_order_subtitle'),
        icon: Icons.sort_rounded,
      ),
    ]);

    if (!settings.activationManaged) {
      entries.addAll([
        TvSettingsEntry(
          id: 'content_source',
          section: 'Content',
          title: l10n.translate('content_source'),
          subtitle: settings.isXtreamSource
              ? l10n.translate('xtream_codes')
              : l10n.translate('live_wave_catalog'),
          icon: Icons.live_tv_rounded,
        ),
        TvSettingsEntry(
          id: 'xtream',
          section: 'Content',
          title: l10n.translate('xtream_login'),
          subtitle: _xtreamCredsLoaded && _xtreamServerController.text.isNotEmpty
              ? _xtreamServerController.text
              : l10n.translate('xtream_login_subtitle'),
          icon: Icons.vpn_key_rounded,
        ),
      ]);
    }

    entries.addAll([
      TvSettingsEntry(
        id: 'downloads',
        section: 'System',
        title: l10n.translate('downloads'),
        subtitle: 'Offline media',
        icon: Icons.download_rounded,
      ),
      TvSettingsEntry(
        id: 'update',
        section: 'System',
        title: 'Software update',
        subtitle: 'Check for new version',
        icon: Icons.system_update_rounded,
      ),
    ]);

    return entries;
  }

  Widget _buildTvSettingDetail(
    String id,
    SettingsProvider settings,
    AppLocalizations l10n,
    ActivationProvider activation,
  ) {
    switch (id) {
      case 'account':
        return _buildTvAccountDetail(activation);
      case 'language':
        return _buildTvLanguageDetail(settings, l10n);
      case 'layout':
        return _buildTvLayoutDetail(settings, l10n);
      case 'category_order':
        return _buildTvCategoryOrderDetail();
      case 'content_source':
        return _buildTvContentSourceDetail(settings, l10n);
      case 'xtream':
        return _buildTvXtreamDetail(settings, l10n);
      case 'downloads':
        return _buildTvDownloadsDetail();
      case 'update':
        return _buildTvUpdateDetail();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTvAccountDetail(ActivationProvider activation) {
    final subtitle = activation.isActive
        ? (activation.expiresAt != null
            ? 'Active until ${_formatShortDate(activation.expiresAt!)}'
            : 'Your subscription is active')
        : activation.isExpired
            ? 'Your subscription has expired'
            : 'View device ID and activation status';

    return TvSettingsActionButton(
      icon: Icons.open_in_new_rounded,
      label: 'Open account',
      subtitle: subtitle,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AccountScreen()),
        );
      },
    );
  }

  Widget _buildTvLanguageDetail(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvSettingsDetailOption(
          title: l10n.translate('english'),
          subtitle: 'English',
          imageAsset: 'assets/flags/b.png',
          selected: settings.language == 'en',
          onSelect: () => settings.setLanguage('en'),
        ),
        TvSettingsDetailOption(
          title: l10n.translate('kurdish'),
          subtitle: 'کوردی',
          imageAsset: 'assets/flags/k.png',
          selected: settings.language == 'ku',
          onSelect: () => settings.setLanguage('ku'),
        ),
      ],
    );
  }

  Widget _buildTvLayoutDetail(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvSettingsDetailOption(
          title: l10n.translate('cinema_tv'),
          subtitle: l10n.translate('landscape'),
          icon: Icons.tv_rounded,
          selected: settings.layoutMode == 'tv',
          onSelect: () => settings.setLayoutMode('tv'),
        ),
        TvSettingsDetailOption(
          title: l10n.translate('pocket_mobile'),
          subtitle: l10n.translate('portrait'),
          icon: Icons.smartphone_rounded,
          selected: settings.layoutMode == 'mobile',
          onSelect: () => settings.setLayoutMode('mobile'),
        ),
      ],
    );
  }

  Widget _buildTvContentSourceDetail(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvSettingsDetailOption(
          title: l10n.translate('live_wave_catalog'),
          subtitle: l10n.translate('firestore_channels'),
          icon: Icons.cloud_rounded,
          selected: settings.contentSource == SettingsProvider.contentSourceFirestore,
          onSelect: () => _switchContentSource(settings, SettingsProvider.contentSourceFirestore),
        ),
        TvSettingsDetailOption(
          title: l10n.translate('xtream_codes'),
          subtitle: l10n.translate('xtream_iptv'),
          icon: Icons.dns_rounded,
          selected: settings.contentSource == SettingsProvider.contentSourceXtream,
          onSelect: () => _switchContentSource(settings, SettingsProvider.contentSourceXtream),
        ),
      ],
    );
  }

  Widget _buildTvXtreamDetail(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildXtreamField(
          controller: _xtreamServerController,
          label: l10n.translate('xtream_server'),
          hint: 'http://your-server.com:2095',
        ),
        const SizedBox(height: 12),
        _buildXtreamField(
          controller: _xtreamUserController,
          label: l10n.translate('xtream_username'),
        ),
        const SizedBox(height: 12),
        _buildXtreamField(
          controller: _xtreamPassController,
          label: l10n.translate('xtream_password'),
          obscure: true,
        ),
        const SizedBox(height: 20),
        TvSettingsActionButton(
          icon: Icons.save_rounded,
          label: l10n.translate('xtream_save_reload'),
          onPressed: () => _saveXtreamCredentials(settings),
        ),
      ],
    );
  }

  Widget _buildTvCategoryOrderDetail() {
    return TvSettingsActionButton(
      icon: Icons.sort_rounded,
      label: AppLocalizations.of(context).translate('category_order'),
      subtitle: AppLocalizations.of(context).translate('category_order_subtitle'),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CategoryOrderScreen()),
        );
      },
    );
  }

  Widget _buildTvDownloadsDetail() {
    return TvSettingsActionButton(
      icon: Icons.offline_pin_rounded,
      label: 'My downloads',
      subtitle: 'Watch offline media',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DownloadsScreen()),
        );
      },
    );
  }

  Widget _buildTvUpdateDetail() {
    return TvSettingsActionButton(
      icon: Icons.system_update_rounded,
      label: 'Check for updates',
      subtitle: 'Keep your app up to date',
      onPressed: () => UpdateService.checkForUpdate(context, showNoUpdate: true),
    );
  }

  // --- Legacy mobile / section builders below ---

  Widget _buildModernHeader(bool isMobile, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.5),
                    blurRadius: 8,
                  )
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.translate('configuration'),
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l10n.translate('settings'),
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isMobile ? 28 : 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.translate('choose_lang'),
          style: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.7),
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }


  Widget _buildLanguageSection(SettingsProvider settings, bool isMobile, AppLocalizations l10n) {
    return _buildPremiumSection(
      isMobile: isMobile,
      icon: Icons.language_rounded,
      title: l10n.translate('language'),
      subtitle: l10n.translate('choose_lang'),
      children: [
        _buildOptionsRow(
          isMobile: isMobile,
          children: [
            _ModernRadioTile(
              title: l10n.translate('english'),
              subtitle: 'English',
              value: 'en',
              imageAsset: 'assets/flags/b.png',
              forceMobile: isMobile,
              groupValue: settings.language,
              onChanged: (val) => settings.setLanguage(val!),
            ),
            _ModernRadioTile(
              title: l10n.translate('kurdish'),
              subtitle: 'کوردی',
              value: 'ku',
              imageAsset: 'assets/flags/k.png',
              forceMobile: isMobile,
              groupValue: settings.language,
              onChanged: (val) => settings.setLanguage(val!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentSourceSection(SettingsProvider settings, bool isMobile, AppLocalizations l10n) {
    return _buildPremiumSection(
      isMobile: isMobile,
      icon: Icons.live_tv_rounded,
      title: l10n.translate('content_source'),
      subtitle: l10n.translate('content_source_subtitle'),
      children: [
        _buildOptionsRow(
          isMobile: isMobile,
          children: [
            _ModernRadioTile(
              title: l10n.translate('live_wave_catalog'),
              subtitle: l10n.translate('firestore_channels'),
              value: SettingsProvider.contentSourceFirestore,
              icon: Icons.cloud_rounded,
              forceMobile: isMobile,
              groupValue: settings.contentSource,
              onChanged: (val) => _switchContentSource(settings, val!),
            ),
            _ModernRadioTile(
              title: l10n.translate('xtream_codes'),
              subtitle: l10n.translate('xtream_iptv'),
              value: SettingsProvider.contentSourceXtream,
              icon: Icons.dns_rounded,
              forceMobile: isMobile,
              groupValue: settings.contentSource,
              onChanged: (val) => _switchContentSource(settings, val!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSection(bool isMobile) {
    return Consumer<ActivationProvider>(
      builder: (context, activation, _) {
        final subtitle = activation.isActive
            ? (activation.expiresAt != null
                ? 'Active • expires ${_formatShortDate(activation.expiresAt!)}'
                : 'Subscription active')
            : activation.isExpired
                ? 'Subscription expired'
                : 'Press OK to view device ID & activation';

        void openAccount() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AccountScreen()),
          );
        }

        return _buildPremiumSection(
          isMobile: isMobile,
          icon: Icons.person_rounded,
          title: 'Account',
          subtitle: 'Device activation & subscription',
          children: [
            _buildOptionsRow(
              isMobile: isMobile,
              children: [
                Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.select)) {
                      openAccount();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(
                    builder: (context) {
                      final isFocused = Focus.of(context).hasFocus;
                      return InkWell(
                        onTap: openAccount,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? double.infinity : double.infinity,
                            minWidth: 140,
                          ),
                          height: 70,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? Colors.white
                                : AppTheme.cardColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                              width: isFocused ? 3 : 1,
                            ),
                            boxShadow: isFocused
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? Colors.black.withOpacity(0.06)
                                      : AppTheme.primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  activation.isActive
                                      ? Icons.verified_rounded
                                      : activation.isExpired
                                          ? Icons.timer_off_rounded
                                          : Icons.hourglass_top_rounded,
                                  color: activation.isActive
                                      ? (isFocused ? Colors.green.shade700 : Colors.green)
                                      : activation.isExpired
                                          ? (isFocused ? Colors.red.shade700 : Colors.red)
                                          : (isFocused ? Colors.orange.shade800 : Colors.orange),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'My Account',
                                      style: TextStyle(
                                        color: isFocused ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isFocused
                                            ? Colors.black54
                                            : Colors.white.withOpacity(0.5),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isFocused ? Colors.black54 : Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildXtreamCredentialsSection(SettingsProvider settings, bool isMobile, AppLocalizations l10n) {
    return _buildPremiumSection(
      isMobile: isMobile,
      icon: Icons.vpn_key_rounded,
      title: l10n.translate('xtream_login'),
      subtitle: l10n.translate('xtream_login_subtitle'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildXtreamField(
              controller: _xtreamServerController,
              label: l10n.translate('xtream_server'),
              hint: 'http://your-server.com:2095',
            ),
            const SizedBox(height: 12),
            _buildXtreamField(
              controller: _xtreamUserController,
              label: l10n.translate('xtream_username'),
            ),
            const SizedBox(height: 12),
            _buildXtreamField(
              controller: _xtreamPassController,
              label: l10n.translate('xtream_password'),
              obscure: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _saveXtreamCredentials(settings),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(l10n.translate('xtream_save_reload')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildXtreamField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8)),
        hintStyle: TextStyle(color: AppTheme.textTertiary.withOpacity(0.5)),
        filled: true,
        fillColor: AppTheme.cardColor.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Future<void> _saveXtreamCredentials(SettingsProvider settings) async {
    final creds = XtreamConfig.normalize(
      XtreamCredentials(
        serverUrl: _xtreamServerController.text.trim(),
        username: _xtreamUserController.text.trim(),
        password: _xtreamPassController.text.trim(),
      ),
    );

    if (!creds.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('xtream_creds_incomplete')),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    await XtreamConfig.save(
      XtreamCredentials(
        serverUrl: creds.serverUrl,
        username: creds.username,
        password: creds.password,
        m3uUrl: creds.m3uUrl,
      ),
    );

    final loginError = await XtreamService().testLogin();
    if (!mounted) return;
    if (loginError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).translate('xtream_login_failed')}\n$loginError',
          ),
          backgroundColor: AppTheme.accentRed,
          duration: const Duration(seconds: 6),
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate('content_source_loading')),
        backgroundColor: AppTheme.cardColor,
      ),
    );

    if (settings.isXtreamSource) {
      await _switchContentSource(settings, SettingsProvider.contentSourceXtream, force: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('xtream_creds_saved')),
          backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
        ),
      );
    }
  }

  Future<void> _switchContentSource(SettingsProvider settings, String source, {bool force = false}) async {
    if (!force && settings.contentSource == source) return;

    await settings.setContentSource(source);
    if (!mounted) return;

    final channelsProvider = Provider.of<ChannelsProvider>(context, listen: false);
    final moviesProvider = Provider.of<MoviesProvider>(context, listen: false);
    final tvShowsProvider = Provider.of<TvShowsProvider>(context, listen: false);

    channelsProvider.setContentSource(source);
    moviesProvider.setContentSource(source);
    tvShowsProvider.setContentSource(source);
    moviesProvider.reset();
    tvShowsProvider.reset();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate('content_source_loading')),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.cardColor,
      ),
    );

    try {
      await Future.wait([
        channelsProvider.fetchChannels(force: true),
        moviesProvider.fetchAllMovies(force: true),
        tvShowsProvider.fetchAllTvShows(force: true),
      ]);
    } catch (_) {
      // Individual providers store their own errors.
    }

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final channelCount = channelsProvider.channels.length;
    final hasErrors = channelsProvider.status == ChannelsStatus.error ||
        moviesProvider.status == MoviesStatus.error ||
        tvShowsProvider.status == TvShowsStatus.error;

    if (hasErrors) {
      final error = channelsProvider.errorMessage ??
          moviesProvider.errorMessage ??
          tvShowsProvider.errorMessage ??
          l10n.translate('content_source_error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 4),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (source == SettingsProvider.contentSourceXtream && channelCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('xtream_empty')),
          duration: const Duration(seconds: 4),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          source == SettingsProvider.contentSourceXtream
              ? l10n.translate('xtream_loaded_count').replaceAll('{count}', '$channelCount')
              : l10n.translate('firestore_loaded'),
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
      ),
    );
  }

  Widget _buildCategoryOrderSection(bool isMobile, AppLocalizations l10n) {
    return _buildPremiumSection(
      isMobile: isMobile,
      icon: Icons.sort_rounded,
      title: l10n.translate('category_order'),
      subtitle: l10n.translate('category_order_subtitle'),
      children: [
        _buildOptionsRow(
          isMobile: isMobile,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CategoryOrderScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.translate('category_order'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserInterfaceSection(SettingsProvider settings, bool isMobile, AppLocalizations l10n) {
    return _buildPremiumSection(
      isMobile: isMobile,
      icon: Icons.grid_view_rounded,
      title: l10n.translate('user_interface'),
      subtitle: l10n.translate('tailor_layout'),
      children: [
        _buildOptionsRow(
          isMobile: isMobile,
          children: [
            _ModernRadioTile(
              title: l10n.translate('cinema_tv'),
              subtitle: l10n.translate('landscape'),
              value: 'tv',
              icon: Icons.tv_rounded,
              forceMobile: isMobile,
              groupValue: settings.layoutMode,
              onChanged: (val) => settings.setLayoutMode(val!),
            ),
            _ModernRadioTile(
              title: l10n.translate('pocket_mobile'),
              subtitle: l10n.translate('portrait'),
              value: 'mobile',
              icon: Icons.smartphone_rounded,
              forceMobile: isMobile,
              groupValue: settings.layoutMode,
              onChanged: (val) => settings.setLayoutMode(val!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadsSection(bool isMobile, AppLocalizations l10n) {
    return _buildPremiumSection(
      isMobile: isMobile,
      icon: Icons.download_rounded,
      title: 'DOWNLOADS',
      subtitle: 'Manage your offline media',
      children: [
        _buildOptionsRow(
          isMobile: isMobile,
          children: [
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && 
                   (event.logicalKey == LogicalKeyboardKey.enter || 
                    event.logicalKey == LogicalKeyboardKey.select)) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsScreen()));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsScreen())),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 220,
                        minWidth: 140,
                      ),
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isFocused ? Colors.white.withOpacity(0.1) : AppTheme.cardColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                          width: isFocused ? 3 : 1,
                        ),
                        boxShadow: isFocused ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ] : [],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.offline_pin_rounded, color: AppTheme.primaryColor),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'My Downloads',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Watch offline media',
                                style: TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpdateSection(bool isMobile, AppLocalizations l10n) {
    return _buildPremiumSection(
      isMobile: isMobile,
      icon: Icons.system_update_rounded,
      title: 'SOFTWARE UPDATE',
      subtitle: 'Keep your app updated for new features',
      children: [
        _buildOptionsRow(
          isMobile: isMobile,
          children: [
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && 
                   (event.logicalKey == LogicalKeyboardKey.enter || 
                    event.logicalKey == LogicalKeyboardKey.select)) {
                  UpdateService.checkForUpdate(context, showNoUpdate: true);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return InkWell(
                    onTap: () => UpdateService.checkForUpdate(context, showNoUpdate: true),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 220,
                        minWidth: 140,
                      ),
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isFocused ? Colors.white.withOpacity(0.1) : AppTheme.cardColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocused ? Colors.white : Colors.white.withOpacity(0.05),
                          width: isFocused ? 3 : 1,
                        ),
                        boxShadow: isFocused ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ] : [],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Check for Update',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'V 1.0.0 (Latest)',
                                style: TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumSection({
    required bool isMobile, 
    required IconData icon, 
    required String title, 
    required String subtitle,
    required List<Widget> children
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary.withOpacity(0.5), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildOptionsRow({required bool isMobile, required List<Widget> children}) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: children,
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    return Focus(
      child: Center(
        child: Column(
          children: [
            Container(
              height: 1,
              width: 100,
              color: Colors.white.withOpacity(0.05),
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
                children: [
                  TextSpan(text: l10n.translate('created_by')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                _handleDeveloperUnlock();
                _handleAdminAccess();
              },
              child: Text(
                'WAVE v2.0', 
                style: TextStyle(
                  color: AppTheme.textTertiary.withOpacity(0.3), 
                  fontSize: 9, 
                  letterSpacing: 1.5
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernRadioTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final IconData? icon;
  final String? imageAsset;
  final bool forceMobile;
  final bool autofocus;
  final Function(String?) onChanged;

  const _ModernRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    this.icon,
    this.imageAsset,
    this.forceMobile = false,
    this.autofocus = false,
    required this.onChanged,
  });

  @override
  State<_ModernRadioTile> createState() => _ModernRadioTileState();
}

class _ModernRadioTileState extends State<_ModernRadioTile> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05, // Subtle scale for settings
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange(bool hasFocus) {
    setState(() => _isFocused = hasFocus);
    if (hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.value == widget.groupValue;
    final isMobile = widget.forceMobile;
    
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
           (event.logicalKey == LogicalKeyboardKey.enter || 
            event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onChanged(widget.value);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => widget.onChanged(widget.value),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 220,
              minWidth: 140,
            ),
            height: 70,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white
                  : (_isFocused ? Colors.white.withOpacity(0.1) : AppTheme.cardColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : (_isFocused ? Colors.white : Colors.white.withOpacity(0.05)),
                width: _isFocused && !isSelected ? 3 : 1,
              ),
              boxShadow: _isFocused && !isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  : isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.black.withOpacity(0.06)
                        : (_isFocused ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(10),
                    image: widget.imageAsset != null 
                      ? DecorationImage(
                          image: AssetImage(widget.imageAsset!),
                          fit: BoxFit.cover,
                        ) 
                      : null,
                  ),
                  child: widget.imageAsset == null && widget.icon != null
                    ? Icon(
                        widget.icon,
                        color: isSelected ? Colors.black87 : Colors.white70,
                        size: 18,
                      )
                    : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : (_isFocused ? Colors.white : AppTheme.textPrimary),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black54
                              : (_isFocused ? Colors.white.withOpacity(0.8) : AppTheme.textSecondary.withOpacity(0.5)),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.check_circle_rounded, color: Colors.black, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

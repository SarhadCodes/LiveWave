import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../widgets/navigation_sidebar.dart';
import '../widgets/app_header.dart';
import '../screens/home_screen_new.dart';
import '../screens/live_channels_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/movies_screen.dart';
import '../screens/tv_shows_screen.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/activation_provider.dart';
import '../providers/channels_provider.dart';
import '../providers/movies_provider.dart';
import '../providers/tv_shows_provider.dart';
import '../widgets/custom_bottom_nav.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';
import '../utils/security_utils.dart';
import '../screens/security_block_screen.dart';
import '../services/update_service.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}


class _AppNavigationState extends State<AppNavigation> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _securityTimer;
  final _sidebarKey = GlobalKey<NavigationSidebarState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSecurityMonitoring();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureActivationReady();
      _focusSidebarOnTv();
    });
    
    // Check for app update on startup
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        UpdateService.checkForUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _securityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckActivation();
    }
  }

  void _focusSidebarOnTv() {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.layoutMode != 'tv') return;
    _sidebarKey.currentState?.requestFocusOnItem(_selectedIndex);
  }

  void _lazyLoadForTab(int index) {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final movies = Provider.of<MoviesProvider>(context, listen: false);
    final tvShows = Provider.of<TvShowsProvider>(context, listen: false);

    movies.setContentSource(settings.contentSource);
    tvShows.setContentSource(settings.contentSource);

    if (index == 2 && movies.status == MoviesStatus.initial) {
      movies.fetchAllMovies();
    } else if (index == 3 && tvShows.status == TvShowsStatus.initial) {
      tvShows.fetchAllTvShows();
    }
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

  Future<void> _recheckActivation() async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.activationManaged) return;
    final activation = Provider.of<ActivationProvider>(context, listen: false);
    final previous = activation.status;
    await activation.recheck(settings);
    if (previous != activation.status && mounted) {
      final channels = Provider.of<ChannelsProvider>(context, listen: false);
      final movies = Provider.of<MoviesProvider>(context, listen: false);
      final tvShows = Provider.of<TvShowsProvider>(context, listen: false);
      channels.setContentSource(settings.contentSource);
      movies.setContentSource(settings.contentSource);
      tvShows.setContentSource(settings.contentSource);
      channels.fetchChannels();
      movies.fetchAllMovies();
      tvShows.fetchAllTvShows();
    }
  }

  void _startSecurityMonitoring() {
    // Check every 5 seconds for background threats
    _securityTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isSecurityAlert = await SecurityUtils.isVpnOrProxyActive();
      if (isSecurityAlert && mounted) {
        // Cancel timer and redirect to block screen
        _securityTimer?.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SecurityBlockScreen()),
          (route) => false, // Remove all previous screens from stack
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context);
    _updateOrientation(settings.layoutMode);
  }

  void _updateOrientation(String layoutMode) {
    Future.microtask(() {
      if (layoutMode == 'tv') {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
  }

  final List<Widget> _screens = [
    const HomeScreenNew(),
    const LiveChannelsScreen(),
    const MoviesScreen(),
    const TvShowsScreen(),
    const SearchScreen(),
    const SettingsScreen(),
  ];

  void _onNavigationItemSelected(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
    });
    _lazyLoadForTab(index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSidebarOnTv());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_selectedIndex != 0) {
          HapticFeedback.selectionClick();
          setState(() => _selectedIndex = 0);
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: Text(l10n.translate('exit'), style: const TextStyle(color: AppTheme.textPrimary)),
            content: Text(l10n.translate('confirm_exit'), style: const TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.translate('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.translate('exit'), style: const TextStyle(color: AppTheme.accentRed)),
              ),
            ],
          ),
        );

        if (shouldExit == true) SystemNavigator.pop();
      },
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final isTvLayout = settings.layoutMode == 'tv';

          // Use AnimatedSwitcher for a smooth, error-free transition
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isTvLayout 
              ? Scaffold(
                  key: const ValueKey('tv_layout'),
                  backgroundColor: AppTheme.backgroundColor,
                  body: Directionality(
                    textDirection: settings.language == 'ku' 
                        ? TextDirection.rtl 
                        : TextDirection.ltr,
                    child: Row(
                      children: [
                        Directionality(
                          textDirection: settings.language == 'ku' 
                              ? TextDirection.rtl 
                              : TextDirection.ltr,
                          child: NavigationSidebar(
                            key: _sidebarKey,
                            selectedIndex: _selectedIndex,
                            onItemSelected: _onNavigationItemSelected,
                          ),
                        ),
                        Expanded(
                          child: Directionality(
                            // Restore the user's language direction for content
                            textDirection: settings.language == 'ku' 
                                ? TextDirection.rtl 
                                : TextDirection.ltr,
                            child: Column(
                              children: [
                                AppHeader(
                                  showSurpriseMe: _selectedIndex == 2 || _selectedIndex == 3,
                                  surpriseType: _selectedIndex == 2 ? 'movie' : 'tv',
                                ),
                                Expanded(
                                  child: _screens[_selectedIndex],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Scaffold(
                  key: const ValueKey('mobile_layout'), // Key helps Flutter swap state
                  backgroundColor: AppTheme.backgroundColor,
                  extendBody: true,
                  appBar: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: SafeArea(
                      child: AppHeader(
                        showSurpriseMe: _selectedIndex == 2 || _selectedIndex == 3,
                        surpriseType: _selectedIndex == 2 ? 'movie' : 'tv',
                      ),
                    ),
                  ),
                  body: SafeArea(
                    bottom: false,
                    child: _screens[_selectedIndex],
                  ),
                  bottomNavigationBar: CustomBottomNav(
                    currentIndex: _selectedIndex,
                    onTap: _onNavigationItemSelected,
                  ),
                ),
          );
        },
      ),
    );
  }
}

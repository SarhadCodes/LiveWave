import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _localizedValues = {
    'en': {
      'home': 'Home',
      'live_tv': 'Live TV',
      'movies': 'Movies',
      'tv_shows': 'TV Shows',
      'favorites': 'Favorites',
      'settings': 'Settings',
      'search_hint': 'Search channels, movies...',
      'categories': 'Categories',
      'featured': 'Featured',
      'trending_movies': 'Trending Movies',
      'trending_tv': 'Trending TV Shows',
      'recent_channels': 'Recent Channels',
      'no_favorites': 'No favorites yet',
      'configuration': 'CONFIGURATION',
      'streaming_engine': 'STREAMING ENGINE',
      'playback_tech': 'Playback technology',
      'internal_engine': 'Internal Engine',
      'vlc_media': 'VLC Media',
      'optimized_hls': 'Optimized for HLS',
      'external_app': 'External App',
      'user_interface': 'USER INTERFACE',
      'tailor_layout': 'Tailor the layout',
      'cinema_tv': 'Cinema TV',
      'landscape': 'Landscape',
      'pocket_mobile': 'Pocket Mobile',
      'portrait': 'Portrait',
      'language': 'LANGUAGE',
      'choose_lang': 'Choose your language',
      'english': 'English',
      'kurdish': 'Kurdish',
      'created_by': 'CREATED WITH ❤️ BY SARHAD',
      'security_alert': 'Security Alert: Please disable VPN or Proxy to watch.',
      'error_channel': 'Channel Not Available',
      'error_try_again': 'Please try again later',
      'scroll_for_details': 'SCROLL FOR DETAILS',
      'watch_now': 'WATCH NOW',
      'episodes': 'Episodes',
      'seasons': 'Seasons',
      'exit': 'Exit',
      'cancel': 'Cancel',
      'confirm_exit': 'Are you sure you want to exit?',
      'surprise_me': 'SURPRISE ME',
      'overview': 'Overview',
      'season': 'Season',
      'no_episodes': 'No episodes found',
      'search': 'Search',
      'search_results': 'Search Results',
      'no_results': 'No results found',
      'search_placeholder': 'Search for your favorite content',
      'search_error': 'Try checking your spelling or use different keywords',
      'see_all': 'See All',
      'retry': 'Retry',
      'featured_badge': 'FEATURED',
      'featured_series': 'FEATURED SERIES',
      'added_to_fav': 'added to favorites',
      'removed_from_fav': 'removed from favorites',
      'scroll_hint_tv': 'SCROLL FOR SESSIONS & EPISODES',
      'episode': 'Episode',
      'watch_trailer': 'Watch Trailer',
      'trailer_error': 'Could not launch trailer',
      'online': 'ONLINE',
      'stream_optimized': 'GLOBAL STREAM OPTIMIZED',
      'subtitle_settings': 'SUBTITLE SETTINGS',
      'text_size': 'TEXT SIZE',
      'appearance': 'APPEARANCE',
      'background': 'Background',
      'on': 'On',
      'off': 'Off',
      'confirm': 'CONFIRM',
      'kurdish_subtitled': 'KURDISH SUBTITLED',
      'anime': 'ANIME',
      'downloads': 'Downloads',
      'content_source': 'LIVE TV SOURCE',
      'content_source_subtitle': 'Switch between catalog and IPTV',
      'live_wave_catalog': 'Live Wave',
      'firestore_channels': 'Default catalog',
      'xtream_codes': 'Xtream Codes',
      'xtream_iptv': 'IPTV test server',
      'content_source_loading': 'Loading channels...',
      'xtream_loaded': 'Xtream channels loaded',
      'xtream_loaded_count': 'Xtream loaded: {count} live channels',
      'xtream_empty': 'No content returned from Xtream server',
      'content_source_error': 'Failed to load Xtream content',
      'firestore_loaded': 'Live Wave catalog restored',
      'xtream_login': 'XTREAM LOGIN',
      'xtream_login_subtitle': 'Use the same Server URL as IPTV Smarters (not the M3U link)',
      'xtream_login_failed': 'Xtream login failed — check server URL and credentials with your provider',
      'xtream_server': 'Server URL',
      'xtream_username': 'Username',
      'xtream_password': 'Password',
      'xtream_save_reload': 'Save & Reload',
      'xtream_creds_saved': 'Xtream credentials saved',
      'xtream_creds_incomplete': 'Please fill server URL, username, and password',
    },
    'ku': {
      'home': 'سەرەتا',
      'live_tv': 'پەخشی ڕاستەوخۆ',
      'movies': 'فیلمەکان',
      'tv_shows': 'دراماکان',
      'favorites': 'دڵخوازەکان',
      'settings': 'ڕێکخستنەکان',
      'search_hint': 'گەڕان بۆ کەناڵ، فیلم...',
      'categories': 'هاوپۆلەکان',
      'featured': 'پێشنیارکراو',
      'trending_movies': 'فیلمە نوێیەکان',
      'trending_tv': 'دراما نوێیەکان',
      'recent_channels': 'کەناڵە بینراوەکان',
      'no_favorites': 'هیچ دڵخوازێک نییە',
      'configuration': 'ڕێکخستنی گشتی',
      'streaming_engine': 'بزوێنەری پەخش',
      'playback_tech': 'تەکنەلۆژیای پەخشکردن',
      'internal_engine': 'بزوێنەری ناوخۆیی',
      'vlc_media': 'بەرنامەی VLC',
      'optimized_hls': 'باشکراوە بۆ HLS',
      'external_app': 'بەرنامەی دەرەکی',
      'user_interface': 'ڕووکاری بەکارهێنەر',
      'tailor_layout': 'شێوازی پیشاندان',
      'cinema_tv': 'سینەمای تیڤی',
      'landscape': 'ئاسۆیی',
      'pocket_mobile': 'مۆبایلی گیرفان',
      'portrait': 'ستوونی',
      'language': 'زمان',
      'choose_lang': 'زمانەکەت هەڵبژێرە',
      'english': 'ئینگلیزی',
      'kurdish': 'کوردی',
      'created_by': 'دروستکراوە بە ❤️ لەلایەن سەرهەد',
      'security_alert': 'ئاگاداری ئەمنی: تکایە VPN یان Proxy بکوژێنەوە.',
      'error_channel': 'کەناڵەکە بەردەست نییە',
      'error_try_again': 'تکایە دواتر هەوڵ بدەرەوە',
      'scroll_for_details': 'بڕۆ خوارەوە بۆ زانیاری زیاتر',
      'watch_now': 'سەیرکردن',
      'episodes': 'ئەڵقەکان',
      'seasons': 'وەرزەکان',
      'exit': 'چوونەدەرەوە',
      'cancel': 'پاشگەزبوونەوە',
      'confirm_exit': 'ئایا دڵنیایت لە چوونەدەرەوە؟',
      'surprise_me': 'سەرسامم بکە',
      'overview': 'کورتە',
      'season': 'وەرز',
      'no_episodes': 'هیچ ئەڵقەیەک نەدۆزرایەوە',
      'search': 'گەڕان',
      'search_results': 'ئەنجامەکانی گەڕان',
      'no_results': 'هیچ ئەنجامێک نەدۆزرایەوە',
      'search_placeholder': 'بگەڕێ بۆ ناوەڕۆکی دڵخوازت',
      'search_error': 'تکایە دڵنیابەرەوە لە نووسینی پیتەکان یان وشەی تر بەکاربهێنە',
      'see_all': 'هەمووی ببینە',
      'retry': 'دووبارە هەوڵ بدەرەوە',
      'featured_badge': 'پێشنیارکراو',
      'featured_series': 'درامای پێشنیارکراو',
      'added_to_fav': 'زیادکرا بۆ دڵخوازەکان',
      'removed_from_fav': 'لادرا لە دڵخوازەکان',
      'scroll_hint_tv': 'بڕۆ خوارەوە بۆ وەرزەکان و ئەڵقەکان',
      'episode': 'ئەڵقەی',
      'watch_trailer': 'تریلەر سەیربکە',
      'trailer_error': 'تریلەرەکە نەکرایەوە',
      'online': 'ڕاستەوخۆ',
      'stream_optimized': 'پەخشی جیهانی باشکراو',
      'subtitle_settings': 'ڕێکخستنی ژێرنووس',
      'text_size': 'قەبارەی نووسین',
      'appearance': 'شێوە',
      'background': 'پاشبنەما',
      'on': 'کارایە',
      'off': 'ناکارایە',
      'confirm': 'جێگیرکردن',
      'kurdish_subtitled': 'ژێرنووسی کوردی',
      'anime': 'ئەنیمی',
      'downloads': 'دابەزاندنەکان',
      'content_source': 'سەرچاوەی کەناڵەکان',
      'content_source_subtitle': 'گۆڕان لە نێوان کاتالۆگ و IPTV',
      'live_wave_catalog': 'Live Wave',
      'firestore_channels': 'کاتالۆگی سەرەکی',
      'xtream_codes': 'Xtream Codes',
      'xtream_iptv': 'سێرڤەری تاقیکردنەوە',
      'content_source_loading': 'کەناڵەکان بار دەکرێن...',
      'xtream_loaded': 'کەناڵەکانی Xtream بارکران',
      'xtream_loaded_count': 'Xtream: {count} کەناڵی ڕاستەوخۆ بارکرا',
      'xtream_empty': 'هیچ ناوەڕۆکێک لە سێرڤەری Xtream نەگەڕایەوە',
      'content_source_error': 'بارکردنی ناوەڕۆکی Xtream سەرکەوتوو نەبوو',
      'firestore_loaded': 'کاتالۆگی Live Wave گەڕایەوە',
      'xtream_login': 'چوونەژوورەوەی Xtream',
      'xtream_login_subtitle': 'هەمان ناونیشانی سێرڤەری IPTV Smarters بەکاربهێنە (نە بەستەری M3U)',
      'xtream_login_failed': 'چوونەژوورەوە سەرکەوتوو نەبوو — ناونیشانی سێرڤەر و زانیاریەکان بپشکنە',
      'xtream_server': 'ناونیشانی سێرڤەر',
      'xtream_username': 'ناوی بەکارهێنەر',
      'xtream_password': 'وشەی نهێنی',
      'xtream_save_reload': 'پاشەکەوت و بارکردنەوە',
      'xtream_creds_saved': 'زانیاری Xtream پاشەکەوت کرا',
      'xtream_creds_incomplete': 'تکایە ناونیشانی سێرڤەر، ناو و وشەی نهێنی پڕ بکەوە',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ku'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => Future.value(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

// Custom Material Localizations for Kurdish to prevent red screen and support RTL
class KurdishMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const KurdishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return KurdishMaterialLocalizations();
  }

  @override
  bool shouldReload(KurdishMaterialLocalizationsDelegate old) => false;
}

class KurdishMaterialLocalizations extends DefaultMaterialLocalizations {
  @override
  TextDirection get textDirection => TextDirection.rtl;
  
  // You can override more methods here if needed for specific Kurdish system labels
}

class KurdishWidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const KurdishWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    return KurdishWidgetsLocalizations();
  }

  @override
  bool shouldReload(KurdishWidgetsLocalizationsDelegate old) => false;
}

class KurdishWidgetsLocalizations extends DefaultWidgetsLocalizations {
  @override
  TextDirection get textDirection => TextDirection.rtl;
}

class KurdishCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const KurdishCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    return const KurdishCupertinoLocalizations();
  }

  @override
  bool shouldReload(KurdishCupertinoLocalizationsDelegate old) => false;
}

class KurdishCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const KurdishCupertinoLocalizations();
}

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
      'created_by': 'CREATED WITH ❤️ BY KURDLOGS',
      'security_alert': 'Security Alert: Please disable VPN or Proxy to watch.',
      'error_channel': 'Channel Not Available',
      'error_try_again': 'Please try again later',
      'scroll_for_details': 'SCROLL FOR DETAILS',
      'watch_now': 'WATCH NOW',
      'resume': 'Resume',
      'continue_watching': 'Continue Watching',
      'min_left': '{m}m left',
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
      'category_order': 'Category Order',
      'category_order_subtitle': 'Reorder Live TV, Movies, and TV Shows rows',
      'reset_order': 'Reset',
      'no_categories_to_order': 'No categories available to reorder yet',
      'category_order_hint': 'Select a category, then use Up/Down to move it',
      'category_order_selected': 'Selected — press OK when done',
      'move_up': 'Move up',
      'move_down': 'Move down',
      'retry': 'Retry',
      'featured_badge': 'FEATURED',
      'featured_series': 'FEATURED SERIES',
      'added_to_fav': 'added to favorites',
      'removed_from_fav': 'removed from favorites',
      'scroll_hint_tv': 'SCROLL FOR SESSIONS & EPISODES',
      'episode': 'Episode',
      'watch_trailer': 'Watch Trailer',
      'cast': 'Cast',
      'biography': 'Biography',
      'acted_in_movies': 'Movies',
      'acted_in_tv': 'TV Shows',
      'no_filmography': 'No titles found',
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
      'live_wave_catalog': 'WAVE',
      'firestore_channels': 'Default catalog',
      'xtream_codes': 'Xtream Codes',
      'xtream_iptv': 'IPTV test server',
      'content_source_loading': 'Loading channels...',
      'xtream_loaded': 'Xtream channels loaded',
      'xtream_loaded_count': 'Xtream loaded: {count} live channels',
      'xtream_empty': 'No content returned from Xtream server',
      'content_source_error': 'Failed to load Xtream content',
      'firestore_loaded': 'WAVE catalog restored',
      'xtream_login': 'XTREAM LOGIN',
      'xtream_login_subtitle': 'Use the same Server URL as IPTV Smarters (not the M3U link)',
      'xtream_login_failed': 'Xtream login failed — check server URL and credentials with your provider',
      'xtream_server': 'Server URL',
      'xtream_username': 'Username',
      'xtream_password': 'Password',
      'xtream_save_reload': 'Save & Reload',
      'xtream_creds_saved': 'Xtream credentials saved',
      'xtream_creds_incomplete': 'Please fill server URL, username, and password',
      'press_left_for_categories': 'Press ◀ for categories',
      'wave': 'MUSIC',
      'wave_subtitle': 'WAVE MUSIC',
      'music_home': 'Home',
      'music_songs': 'Songs',
      'music_albums': 'Albums',
      'music_artists': 'Artists',
      'music_playlists': 'Playlists',
      'music_liked': 'Liked',
      'music_recent': 'Recently Played',
      'music_search': 'Search',
      'music_continue': 'Continue Listening',
      'music_quick_picks': 'Quick Picks',
      'music_popular_songs': 'Popular Songs',
      'music_popular_artists': 'Popular Artists',
      'music_new_releases': 'New Releases',
      'music_trending': 'Trending',
      'music_recommended': 'Recommended',
      'wave_featured': 'FEATURED',
      'wave_search': 'Wave Search',
      'wave_search_hint': 'Search Wave videos and creators',
      'wave_search_empty': 'Find public videos, creators, and live streams',
      'wave_search_videos': 'Videos',
      'wave_search_creators': 'Creators',
      'wave_search_live': 'Live',
      'wave_chip_forYou': 'For You',
      'wave_chip_trending': 'Trending',
      'wave_chip_live': 'Live',
      'wave_chip_music': 'Music',
      'wave_chip_gaming': 'Gaming',
      'wave_chip_technology': 'Technology',
      'wave_chip_podcasts': 'Podcasts',
      'wave_chip_documentaries': 'Documentaries',
      'wave_chip_news': 'News',
      'wave_trending_now': 'Trending Now',
      'wave_live_now': 'Live Now',
      'wave_from_followed': 'From Creators You Follow',
      'wave_recently_watched': 'Recently Watched',
      'wave_watch_later': 'Watch Later',
      'wave_save': 'Save',
      'wave_share': 'Share',
      'wave_fullscreen': 'Fullscreen',
      'wave_exit_fullscreen': 'Exit fullscreen',
      'wave_follow': 'Follow',
      'wave_following': 'Following',
      'wave_follow_disclaimer': 'Follow inside WAVE — this is not a YouTube subscription',
      'wave_followers_meta': 'followers',
      'wave_more_from_creator': 'More from this creator',
      'wave_more_to_watch': 'More to Watch',
      'wave_library': 'Wave Library',
      'wave_library_history': 'History',
      'wave_library_later': 'Watch Later',
      'wave_library_saved': 'Saved',
      'wave_library_following': 'Following',
      'wave_creator_videos': 'Videos',
      'wave_creator_live': 'Live',
      'wave_creator_popular': 'Popular',
      'wave_connect_error': 'Wave couldn\'t connect. Try again.',
      'wave_quota': 'Wave has reached today\'s discovery limit. Try again later.',
      'wave_api_invalid': 'This YouTube API key is not valid for Wave.',
      'wave_api_restricted': 'This YouTube API key is blocked by its Google Cloud restrictions. Restrict it to YouTube Data API v3, keep the Android package and SHA-1, then retry.',
      'wave_api_not_enabled': 'Enable YouTube Data API v3 for this key in Google Cloud Console, then retry.',
      'wave_video_unavailable': 'This video isn\'t available.',
      'wave_embedding_disabled': 'This video can\'t be played here.',
      'wave_nothing_found': 'Nothing found for this search.',
      'wave_empty_home': 'Nothing to show here yet.',
      'wave_empty_library': 'Nothing saved in Wave yet.',
      'wave_empty_following': 'You are not following any creators in WAVE yet.',
      'wave_api_needed': 'Wave needs a YouTube Data API key',
      'wave_api_needed_body': 'Add a YouTube Data API v3 key to browse public videos. Restrict the key to this app in Google Cloud Console. See WAVE_SETUP.md.',
      'wave_api_hint': 'YouTube Data API key',
      'wave_api_save': 'Save & browse Wave',
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
      'created_by': 'دروستکراوە بە ❤️ لەلایەن KURDLOGS',
      'security_alert': 'ئاگاداری ئەمنی: تکایە VPN یان Proxy بکوژێنەوە.',
      'error_channel': 'کەناڵەکە بەردەست نییە',
      'error_try_again': 'تکایە دواتر هەوڵ بدەرەوە',
      'scroll_for_details': 'بڕۆ خوارەوە بۆ زانیاری زیاتر',
      'watch_now': 'سەیرکردن',
      'resume': 'بەردەوامبدە',
      'continue_watching': 'بەردەوامبوون',
      'min_left': '{m} خولەک ماوە',
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
      'category_order': 'ڕیزبندی هاوپۆل',
      'category_order_subtitle': 'ڕیزبندی ڕیزەکانی پەخشی ڕاستەوخۆ، فیلم و دراما',
      'reset_order': 'ڕێکخستنەوە',
      'no_categories_to_order': 'هێشتا هاوپۆلێک نییە بۆ ڕیزکردن',
      'category_order_hint': 'هاوپۆلێک هەڵبژێرە، پاشان سەرەوە/خوارەوە بۆ گۆڕینی شوێن',
      'category_order_selected': 'هەڵبژێردرا — OK بگرە کاتێک تەواو بوو',
      'move_up': 'بجوێژە سەرەوە',
      'move_down': 'بجوێژە خوارەوە',
      'retry': 'دووبارە هەوڵ بدەرەوە',
      'featured_badge': 'پێشنیارکراو',
      'featured_series': 'درامای پێشنیارکراو',
      'added_to_fav': 'زیادکرا بۆ دڵخوازەکان',
      'removed_from_fav': 'لادرا لە دڵخوازەکان',
      'scroll_hint_tv': 'بڕۆ خوارەوە بۆ وەرزەکان و ئەڵقەکان',
      'episode': 'ئەڵقەی',
      'watch_trailer': 'تریلەر سەیربکە',
      'cast': 'ئەکتەرەکان',
      'biography': 'ژیاننامە',
      'acted_in_movies': 'فیلمەکان',
      'acted_in_tv': 'دراماکان',
      'no_filmography': 'هیچ ناونیشانێک نەدۆزرایەوە',
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
      'live_wave_catalog': 'WAVE',
      'firestore_channels': 'کاتالۆگی سەرەکی',
      'xtream_codes': 'Xtream Codes',
      'xtream_iptv': 'سێرڤەری تاقیکردنەوە',
      'content_source_loading': 'کەناڵەکان بار دەکرێن...',
      'xtream_loaded': 'کەناڵەکانی Xtream بارکران',
      'xtream_loaded_count': 'Xtream: {count} کەناڵی ڕاستەوخۆ بارکرا',
      'xtream_empty': 'هیچ ناوەڕۆکێک لە سێرڤەری Xtream نەگەڕایەوە',
      'content_source_error': 'بارکردنی ناوەڕۆکی Xtream سەرکەوتوو نەبوو',
      'firestore_loaded': 'کاتالۆگی WAVE گەڕایەوە',
      'xtream_login': 'چوونەژوورەوەی Xtream',
      'xtream_login_subtitle': 'هەمان ناونیشانی سێرڤەری IPTV Smarters بەکاربهێنە (نە بەستەری M3U)',
      'xtream_login_failed': 'چوونەژوورەوە سەرکەوتوو نەبوو — ناونیشانی سێرڤەر و زانیاریەکان بپشکنە',
      'xtream_server': 'ناونیشانی سێرڤەر',
      'xtream_username': 'ناوی بەکارهێنەر',
      'xtream_password': 'وشەی نهێنی',
      'xtream_save_reload': 'پاشەکەوت و بارکردنەوە',
      'xtream_creds_saved': 'زانیاری Xtream پاشەکەوت کرا',
      'xtream_creds_incomplete': 'تکایە ناونیشانی سێرڤەر، ناو و وشەی نهێنی پڕ بکەوە',
      'press_left_for_categories': '◀ بۆ هاوپۆلەکان',
      'wave': 'میوزیک',
      'wave_subtitle': 'WAVE MUSIC',
      'music_home': 'سەرەتا',
      'music_songs': 'گۆرانی',
      'music_albums': 'ئەلبومەکان',
      'music_artists': 'هونەرمەندان',
      'music_playlists': 'لیستەکان',
      'music_liked': 'دڵخواز',
      'music_recent': 'دوایین لێدراو',
      'music_search': 'گەڕان',
      'music_continue': 'بەردەوام بە',
      'music_quick_picks': 'هەڵبژاردە',
      'music_popular_songs': 'گۆرانی بەناوبانگ',
      'music_popular_artists': 'هونەرمەندی بەناوبانگ',
      'music_new_releases': 'نوێیەکان',
      'music_trending': 'ترێند',
      'music_recommended': 'پێشنیارکراو',
      'wave_featured': 'تایبەت',
      'wave_search': 'گەڕانی Wave',
      'wave_search_hint': 'بگەڕێ بۆ ڤیدیۆ و دروستکەر',
      'wave_search_empty': 'ڤیدیۆ، دروستکەر و پەخشی ڕاستەوخۆ بدۆزەرەوە',
      'wave_search_videos': 'ڤیدیۆ',
      'wave_search_creators': 'دروستکەران',
      'wave_search_live': 'ڕاستەوخۆ',
      'wave_chip_forYou': 'بۆ تۆ',
      'wave_chip_trending': 'باو',
      'wave_chip_live': 'ڕاستەوخۆ',
      'wave_chip_music': 'میوزیک',
      'wave_chip_gaming': 'یاری',
      'wave_chip_technology': 'تەکنەلۆژیا',
      'wave_chip_podcasts': 'پۆدکاست',
      'wave_chip_documentaries': 'بەڵگەنامەیی',
      'wave_chip_news': 'هەواڵ',
      'wave_trending_now': 'ئێستا باو',
      'wave_live_now': 'ئێستا ڕاستەوخۆ',
      'wave_from_followed': 'لە دروستکەرانی بەدواداچوو',
      'wave_recently_watched': 'دوایین بینراو',
      'wave_watch_later': 'دواتر سەیری بکە',
      'wave_save': 'پاشەکەوت',
      'wave_share': 'هاوبەشکردن',
      'wave_fullscreen': 'پڕی شاشە',
      'wave_exit_fullscreen': 'دەرچوون لە پڕی شاشە',
      'wave_follow': 'بەدواداچوون',
      'wave_following': 'بەدوادەچیت',
      'wave_follow_disclaimer': 'بەدواداچوون لەناو WAVE — ئەمە بەشداری یوتیوب نییە',
      'wave_followers_meta': 'شوێنکەوتوو',
      'wave_more_from_creator': 'زیاتر لەم دروستکەرە',
      'wave_more_to_watch': 'زیاتر بۆ سەیرکردن',
      'wave_library': 'کتێبخانەی Wave',
      'wave_library_history': 'مێژوو',
      'wave_library_later': 'دواتر',
      'wave_library_saved': 'پاشەکەوتکراو',
      'wave_library_following': 'بەدواداچوون',
      'wave_creator_videos': 'ڤیدیۆ',
      'wave_creator_live': 'ڕاستەوخۆ',
      'wave_creator_popular': 'باوترین',
      'wave_connect_error': 'Wave پەیوەندی نەکرد. دووبارە هەوڵ بدەرەوە.',
      'wave_quota': 'Wave گەیشتە سنووری ئەمڕۆ. دواتر هەوڵ بدەرەوە.',
      'wave_api_invalid': 'ئەم کلیلی YouTube بۆ Wave دروست نییە.',
      'wave_api_restricted': 'ئەم کلیلی YouTube لەلایەن Google Cloud بلۆک کراوە. تەنها YouTube Data API v3، پاکێج و SHA-1 دابنێ، پاشان دووبارە هەوڵ بدەرەوە.',
      'wave_api_not_enabled': 'YouTube Data API v3 بۆ ئەم کلیلە چالاک بکە، پاشان دووبارە هەوڵ بدەرەوە.',
      'wave_video_unavailable': 'ئەم ڤیدیۆیە بەردەست نییە.',
      'wave_embedding_disabled': 'ئەم ڤیدیۆیە لێرە پەخش ناکرێت.',
      'wave_nothing_found': 'هیچ شتێک بۆ ئەم گەڕانە نەدۆزرایەوە.',
      'wave_empty_home': 'هێشتا هیچ شتێک نییە بۆ پیشاندان.',
      'wave_empty_library': 'هێشتا هیچ شتێک لە Wave پاشەکەوت نەکراوە.',
      'wave_empty_following': 'هێشتا هیچ دروستکەرێک لە WAVE بەدوادا ناچیت.',
      'wave_api_needed': 'Wave پێویستی بە کلیلی YouTube Data API هەیە',
      'wave_api_needed_body': 'کلیلێکی YouTube Data API v3 زیاد بکە. لە Google Cloud Console سنوورداری بکە. WAVE_SETUP.md ببینە.',
      'wave_api_hint': 'کلیلی YouTube Data API',
      'wave_api_save': 'پاشەکەوت و دەستپێکردن',
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

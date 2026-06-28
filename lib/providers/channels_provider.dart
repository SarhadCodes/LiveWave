import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../services/firestore_service.dart';
import '../services/xtream_service.dart';
import 'settings_provider.dart';

enum ChannelsStatus { initial, loading, success, error }

class ChannelsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final XtreamService _xtreamService = XtreamService();
  static const String _favoritesKey = 'favorite_channels';

  String _contentSource = SettingsProvider.contentSourceFirestore;

  ChannelsStatus _status = ChannelsStatus.initial;
  List<Channel> _channels = [];
  String? _errorMessage;
  String? _selectedCategory;
  final Set<String> _favoriteChannelIds = {};
  String _language = 'en';
  final Map<String, List<Channel>> _groupedChannels = {};
  List<String> _categoryList = [];

  ChannelsStatus get status => _status;
  List<Channel> get channels => _channels;
  String? get errorMessage => _errorMessage;
  String? get selectedCategory => _selectedCategory;
  String get contentSource => _contentSource;
  bool get isXtreamSource => _contentSource == SettingsProvider.contentSourceXtream;

  void setContentSource(String source) {
    _contentSource = source;
  }

  void updateLanguage(String lang) {
    if (_language != lang) {
      _language = lang;
      _updateGroups();
      notifyListeners();
    }
  }

  // Get favorite channels
  List<Channel> get favoriteChannels {
    return _channels.where((channel) => _favoriteChannelIds.contains(channel.id)).toList();
  }

  // Get cached category list
  List<String> get categories => _categoryList;

  // Get filtered channels for current selection
  List<Channel> get filteredChannels {
    if (_selectedCategory == null || _selectedCategory == 'ALL') return _channels;
    return getChannelsByCategory(_selectedCategory!);
  }

  // Get channels for a specific category from cache
  List<Channel> getChannelsByCategory(String category) {
    return _groupedChannels[category.toUpperCase()] ?? [];
  }

  void _updateGroups() {
    _groupedChannels.clear();
    
    // Filter channels that have a valid category for the current language
    final activeChannels = _channels.where((c) => c.getDisplayCategory(_language).trim().isNotEmpty).toList();
    
    for (var channel in activeChannels) {
      final displayCat = channel.getDisplayCategory(_language);
      final cat = displayCat.toUpperCase();
      _groupedChannels.putIfAbsent(cat, () => []).add(channel);
    }
    
    final favorites = favoriteChannels;
    final String favKey = _language == 'ku' ? 'دڵخوازەکان' : 'FAVORITES';
    
    if (favorites.isNotEmpty) {
      _groupedChannels[favKey.toUpperCase()] = favorites;
    }

    final categorySet = activeChannels.map((c) => c.getDisplayCategory(_language).toUpperCase()).toSet();
    final favKeyUpper = favKey.toUpperCase();
    final List<String> playlistOrder = [];
    for (final channel in activeChannels) {
      final cat = channel.getDisplayCategory(_language).toUpperCase();
      if (cat.isEmpty || cat == favKeyUpper || playlistOrder.contains(cat)) {
        continue;
      }
      if (cat != 'NEWS' && cat != 'هەواڵ') {
        playlistOrder.add(cat);
      }
    }

    final List<String> sortedOthers = playlistOrder.isNotEmpty
        ? playlistOrder
        : (categorySet
                .where((c) =>
                    c != 'NEWS' &&
                    c != 'هەواڵ' &&
                    c != favKeyUpper)
                .toList()
              ..sort());
    
    final List<String> finalCategories = [];
    if (_groupedChannels.containsKey(favKey.toUpperCase())) finalCategories.add(favKey.toUpperCase());
    
    // Check for NEWS in both English and Kurdish
    if (categorySet.contains('NEWS')) finalCategories.add('NEWS');
    if (categorySet.contains('هەواڵ')) finalCategories.add('هەواڵ');
    
    finalCategories.addAll(sortedOthers);
    _categoryList = finalCategories;
  }

  // Check if a channel is favorite
  bool isFavorite(String channelId) {
    return _favoriteChannelIds.contains(channelId);
  }

  // Load favorites from SharedPreferences
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      _favoriteChannelIds.clear();
      _favoriteChannelIds.addAll(favorites);
      _updateGroups();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  // Save favorites to SharedPreferences
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, _favoriteChannelIds.toList());
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String channelId) async {
    if (_favoriteChannelIds.contains(channelId)) {
      _favoriteChannelIds.remove(channelId);
    } else {
      _favoriteChannelIds.add(channelId);
    }
    _updateGroups();
    notifyListeners();
    await _saveFavorites();
  }

  // Fetch channels from Firestore
  Future<void> fetchChannels({bool force = false}) async {
    if (!force && _status == ChannelsStatus.loading) return;

    _status = ChannelsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadFavorites();
      if (_contentSource == SettingsProvider.contentSourceXtream) {
        _channels = await _xtreamService.getLiveChannels();
      } else {
        _channels = await _firestoreService.getActiveChannels();
      }
      _updateGroups();
      _status = ChannelsStatus.success;
    } catch (e) {
      debugPrint('[ChannelsProvider] fetchChannels error: $e');
      _status = ChannelsStatus.error;
      _errorMessage = e.toString();
      _channels = [];
      _groupedChannels.clear();
      _categoryList = [];
    }
    notifyListeners();
  }

  // Listen to real-time channel updates
  void listenToChannels() {
    _status = ChannelsStatus.loading;
    notifyListeners();
    _loadFavorites();

    _firestoreService.getActiveChannelsStream().listen(
      (channels) {
        _channels = channels;
        _updateGroups();
        _status = ChannelsStatus.success;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _status = ChannelsStatus.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // Set selected category filter
  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Filter channels by category
  List<Channel> filterByCategory(String category) {
    if (category == 'ALL') return _channels;
    return getChannelsByCategory(category);
  }

  // Retry fetching channels
  Future<void> retry() async {
    await fetchChannels();
  }

  // Reset to initial state
  void reset() {
    _status = ChannelsStatus.initial;
    _channels = [];
    _errorMessage = null;
    _selectedCategory = null;
    _favoriteChannelIds.clear();
    notifyListeners();
  }
}

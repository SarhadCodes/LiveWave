import '../providers/channels_provider.dart';
import '../providers/favorites_provider.dart';
import '../services/activation_service.dart';

/// Clears user-specific data when a playlist / activation code expires.
abstract final class UserContentCleanup {
  static Future<void> onActivationStatusChange({
    required ActivationStatus previous,
    required ActivationStatus current,
    required ChannelsProvider channels,
    required FavoritesProvider favorites,
  }) async {
    if (current != ActivationStatus.expired ||
        previous == ActivationStatus.expired) {
      return;
    }
    await Future.wait([
      channels.clearFavorites(),
      favorites.clearAllFavorites(),
    ]);
  }
}

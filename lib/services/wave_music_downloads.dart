/// Offline download contract. Not implemented yet — do not report tracks as downloaded.
class WaveMusicDownloadStore {
  const WaveMusicDownloadStore();

  bool get isSupported => false;

  Future<bool> isDownloaded(String trackId) async => false;

  Future<void> enqueue(String trackId) async {
    throw UnsupportedError('Offline music downloads are not implemented yet.');
  }
}

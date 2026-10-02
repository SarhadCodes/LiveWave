import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// iOS WAVE MUSIC engine. Android keeps Media3 and is not registered here.
final class WaveMusicIosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let player = AVPlayer()
  private let loader = WaveYtResourceLoader()
  private var eventSink: FlutterEventSink?
  private var timeObserver: Any?
  private var endObserver: NSObjectProtocol?
  private var stallObserver: NSObjectProtocol?
  private var failObserver: NSObjectProtocol?
  private var interruptionObserver: NSObjectProtocol?
  private var statusObserver: NSKeyValueObservation?
  private var timeControlObserver: NSKeyValueObservation?
  private var repeatMode = "off"
  private var commandsBound = false
  private var sessionReady = false
  private var currentId = ""
  private var currentTitle = ""
  private var currentArtist = ""
  private var currentArtwork: String?
  private var reportedError = false
  private var loadGeneration = 0
  private var pendingPlay = false
  private var pendingResult: FlutterResult?
  private var pendingGeneration = 0
  private var readyTimeout: DispatchWorkItem?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "wave_music_player",
      binaryMessenger: registrar.messenger()
    )
    let events = FlutterEventChannel(
      name: "wave_music_player/events",
      binaryMessenger: registrar.messenger()
    )
    let instance = WaveMusicIosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    events.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "warmUp":
      activateSession()
      bindCommands()
      result(nil)
    case "setQueue":
      let args = call.arguments as? [String: Any] ?? [:]
      let items = args["items"] as? [[String: Any]] ?? []
      let start = args["startIndex"] as? Int ?? 0
      let play = args["play"] as? Bool ?? true
      repeatMode = args["repeat"] as? String ?? repeatMode
      guard !items.isEmpty else {
        result(nil)
        return
      }
      let index = min(max(0, start), items.count - 1)
      playItem(items[index], play: play, result: result)
      emit("index", ["index": index, "id": currentId])
    case "play":
      activateSession()
      pendingPlay = true
      if player.currentItem?.status == .readyToPlay {
        player.play()
        emit("playing", ["playing": true])
        updateNowPlaying(rate: 1)
        logState("play command")
      } else {
        NSLog("[WAVE_IOS_MUSIC] play deferred until item ready status=%@", statusName(player.currentItem?.status))
      }
      result(nil)
    case "pause":
      pendingPlay = false
      player.pause()
      emit("paused", [:])
      updateNowPlaying(rate: 0)
      result(nil)
    case "next":
      emit("skipNext", [:])
      result(nil)
    case "previous":
      if currentSeconds() > 3 {
        seek(to: 0)
      } else {
        emit("skipPrevious", [:])
      }
      result(nil)
    case "seek":
      let args = call.arguments as? [String: Any] ?? [:]
      let ms = (args["positionMs"] as? NSNumber)?.doubleValue ?? 0
      seek(to: ms / 1000)
      result(nil)
    case "setShuffle":
      result(nil)
    case "setRepeat":
      let args = call.arguments as? [String: Any] ?? [:]
      repeatMode = args["mode"] as? String ?? "off"
      result(nil)
    case "setVolume":
      let args = call.arguments as? [String: Any] ?? [:]
      let volume = (args["volume"] as? NSNumber)?.floatValue ?? 1
      player.volume = min(1, max(0, volume))
      result(nil)
    case "stop":
      pendingPlay = false
      finishPending(error: nil)
      player.pause()
      replaceItem(nil)
      emit("paused", [:])
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func activateSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true, options: [])
      sessionReady = true
      NSLog("[WAVE_IOS_MUSIC] AVAudioSession playback active")
    } catch {
      sessionReady = false
      NSLog("[WAVE_IOS_MUSIC] AVAudioSession failed %@", error.localizedDescription)
    }
    UIApplication.shared.beginReceivingRemoteControlEvents()
    if interruptionObserver == nil {
      interruptionObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: session,
        queue: .main
      ) { [weak self] note in
        self?.handleInterruption(note)
      }
    }
  }

  private func handleInterruption(_ note: Notification) {
    guard
      let info = note.userInfo,
      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else { return }
    switch type {
    case .began:
      NSLog("[WAVE_IOS_MUSIC] interruption began")
      emit("paused", [:])
      updateNowPlaying(rate: 0)
    case .ended:
      let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
        .flatMap(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
      NSLog("[WAVE_IOS_MUSIC] interruption ended shouldResume=%@", options.contains(.shouldResume) ? "1" : "0")
      activateSession()
      if options.contains(.shouldResume) || pendingPlay {
        player.play()
        emit("playing", ["playing": true])
        updateNowPlaying(rate: 1)
      }
    @unknown default:
      break
    }
  }

  private func bindCommands() {
    if commandsBound { return }
    commandsBound = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.isEnabled = true
    center.pauseCommand.isEnabled = true
    center.togglePlayPauseCommand.isEnabled = true
    center.nextTrackCommand.isEnabled = true
    center.previousTrackCommand.isEnabled = true
    center.changePlaybackPositionCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      self.activateSession()
      self.pendingPlay = true
      self.player.play()
      self.emit("playing", ["playing": true])
      self.updateNowPlaying(rate: 1)
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      self.pendingPlay = false
      self.player.pause()
      self.emit("paused", [:])
      self.updateNowPlaying(rate: 0)
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      if self.player.timeControlStatus == .playing {
        self.pendingPlay = false
        self.player.pause()
        self.emit("paused", [:])
        self.updateNowPlaying(rate: 0)
      } else {
        self.activateSession()
        self.pendingPlay = true
        self.player.play()
        self.emit("playing", ["playing": true])
        self.updateNowPlaying(rate: 1)
      }
      return .success
    }
    center.nextTrackCommand.addTarget { [weak self] _ in
      self?.emit("skipNext", [:])
      return .success
    }
    center.previousTrackCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      if self.currentSeconds() > 3 {
        self.seek(to: 0)
      } else {
        self.emit("skipPrevious", [:])
      }
      return .success
    }
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let position = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.seek(to: position.positionTime)
      return .success
    }
  }

  private func playItem(_ raw: [String: Any], play: Bool, result: @escaping FlutterResult) {
    activateSession()
    bindCommands()
    if pendingResult != nil {
      finishPending(
        error: FlutterError(code: "replaced", message: "Track replaced before ready", details: nil)
      )
    }

    let urlString = (raw["audioUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let sourceURL = URL(string: urlString), urlString.hasPrefix("http") else {
      let message = "This track is unavailable to stream."
      emit("error", ["message": message])
      result(FlutterError(code: "unavailable", message: message, details: nil))
      return
    }

    currentId = raw["id"] as? String ?? ""
    currentTitle = raw["title"] as? String ?? ""
    currentArtist = raw["artist"] as? String ?? ""
    currentArtwork = raw["artworkUrl"] as? String
    reportedError = false
    pendingPlay = play
    loadGeneration += 1
    let generation = loadGeneration
    pendingGeneration = generation
    pendingResult = result

    let headers = stringMap(raw["headers"])
    let mime = (raw["mimeType"] as? String) ?? ""
    NSLog(
      "[WAVE_IOS_MUSIC] setQueue title=%@ host=%@ path=%@ mime=%@ headers=%d",
      currentTitle,
      sourceURL.host ?? "",
      sourceURL.path,
      mime,
      headers.count
    )

    // googlevideo rejects non-Range probes with 403. Route through a custom
    // scheme so we can force Range requests while keeping AVPlayer's item.
    guard let playbackURL = WaveYtResourceLoader.playbackURL(from: sourceURL) else {
      let message = "Invalid stream URL"
      emit("error", ["message": message])
      finishPending(error: FlutterError(code: "invalid_url", message: message, details: nil))
      return
    }
    loader.cancelAll()
    loader.headers = headers
    loader.logLabel = currentTitle

    let asset = AVURLAsset(url: playbackURL)
    asset.resourceLoader.setDelegate(loader, queue: loader.queue)
    let item = AVPlayerItem(asset: asset)
    replaceItem(item)
    observe(item, generation: generation)
    readyTimeout?.cancel()
    let timeout = DispatchWorkItem { [weak self] in
      guard let self, generation == self.loadGeneration, self.pendingResult != nil else { return }
      self.fail(
        message: "Timed out waiting for AVPlayerItem",
        item: item,
        generation: generation
      )
    }
    readyTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
  }

  private func replaceItem(_ item: AVPlayerItem?) {
    if item == nil {
      loader.cancelAll()
    }
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
      self.endObserver = nil
    }
    if let stallObserver {
      NotificationCenter.default.removeObserver(stallObserver)
      self.stallObserver = nil
    }
    if let failObserver {
      NotificationCenter.default.removeObserver(failObserver)
      self.failObserver = nil
    }
    statusObserver = nil
    timeControlObserver = nil
    player.replaceCurrentItem(with: item)
    guard item != nil else { return }
    let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      self?.emitPosition(time)
    }
  }

  private func observe(_ item: AVPlayerItem, generation: Int) {
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self, generation == self.loadGeneration else { return }
      if self.repeatMode == "one" {
        self.seek(to: 0)
        self.player.play()
        return
      }
      self.pendingPlay = false
      self.emit("ended", [:])
    }
    failObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] note in
      guard let self, generation == self.loadGeneration else { return }
      let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
      self.fail(
        message: error?.localizedDescription ?? "Playback failed before end",
        item: item,
        generation: generation
      )
    }
    statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
      guard let self, generation == self.loadGeneration else { return }
      self.onItemStatus(item, generation: generation)
    }
    timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
      guard let self, generation == self.loadGeneration else { return }
      self.logState("timeControl")
      if player.timeControlStatus == .playing {
        self.emit("playing", ["playing": true])
        self.updateNowPlaying(rate: 1)
      } else if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
        self.emit("buffering", [:])
      }
    }
    stallObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemPlaybackStalled,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self, generation == self.loadGeneration else { return }
      self.emit("buffering", [:])
      NSLog("[WAVE_IOS_MUSIC] stalled title=%@", self.currentTitle)
    }
  }

  private func onItemStatus(_ item: AVPlayerItem, generation: Int) {
    switch item.status {
    case .readyToPlay:
      NSLog("[WAVE_IOS_MUSIC] AVPlayerItem ready title=%@", currentTitle)
      if pendingPlay {
        activateSession()
        player.play()
        logState("after play()")
      } else {
        emit("paused", [:])
        updateNowPlaying(rate: 0)
      }
      loadArtwork()
      finishPending(error: nil)
    case .failed:
      fail(
        message: item.error?.localizedDescription ?? player.error?.localizedDescription ?? "Playback failed",
        item: item,
        generation: generation
      )
    case .unknown:
      NSLog("[WAVE_IOS_MUSIC] AVPlayerItem status unknown title=%@", currentTitle)
    @unknown default:
      break
    }
  }

  private func fail(message: String, item: AVPlayerItem, generation: Int) {
    guard generation == loadGeneration, !reportedError else { return }
    reportedError = true
    pendingPlay = false
    let detail = [
      "message": message,
      "itemError": item.error?.localizedDescription ?? "",
      "playerError": player.error?.localizedDescription ?? "",
      "status": statusName(item.status),
      "timeControl": timeControlName(player.timeControlStatus),
      "waiting": waitingReasonName(player.reasonForWaitingToPlay),
    ]
    NSLog(
      "[WAVE_IOS_MUSIC] FAIL title=%@ message=%@ item=%@ player=%@ waiting=%@",
      currentTitle,
      message,
      item.error?.localizedDescription ?? "",
      player.error?.localizedDescription ?? "",
      waitingReasonName(player.reasonForWaitingToPlay)
    )
    emit("error", detail)
    finishPending(error: FlutterError(code: "playback_failed", message: message, details: detail))
    updateNowPlaying(rate: 0)
  }

  private func finishPending(error: FlutterError?) {
    readyTimeout?.cancel()
    readyTimeout = nil
    guard let pendingResult else { return }
    self.pendingResult = nil
    if let error {
      pendingResult(error)
    } else {
      pendingResult(nil)
    }
  }

  private func seek(to seconds: Double) {
    let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
    player.seek(to: time)
    updateNowPlaying(rate: player.timeControlStatus == .playing ? 1 : 0)
  }

  private func currentSeconds() -> Double {
    let seconds = player.currentTime().seconds
    return seconds.isFinite ? seconds : 0
  }

  private func emitPosition(_ time: CMTime) {
    let position = time.seconds.isFinite ? time.seconds : 0
    let duration = player.currentItem?.duration.seconds ?? 0
    let durationSeconds = duration.isFinite ? duration : 0
    emit("position", [
      "positionMs": Int(position * 1000),
      "durationMs": Int(durationSeconds * 1000),
    ])
    if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
      emit("buffering", [:])
    }
  }

  private func updateNowPlaying(rate: Double) {
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: currentTitle,
      MPMediaItemPropertyArtist: currentArtist,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: currentSeconds(),
      MPNowPlayingInfoPropertyPlaybackRate: rate,
    ]
    let duration = player.currentItem?.duration.seconds ?? 0
    if duration.isFinite && duration > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = duration
    }
    if let artwork = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] {
      info[MPMediaItemPropertyArtwork] = artwork
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func loadArtwork() {
    guard let raw = currentArtwork, let url = URL(string: raw) else { return }
    let title = currentTitle
    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let self, let data, let image = UIImage(data: data), self.currentTitle == title else { return }
      let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
      DispatchQueue.main.async {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    }.resume()
  }

  private func emit(_ type: String, _ payload: [String: Any]) {
    var event = payload
    event["type"] = type
    if Thread.isMainThread {
      eventSink?(event)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.eventSink?(event)
      }
    }
  }

  private func stringMap(_ raw: Any?) -> [String: String] {
    guard let map = raw as? [String: Any] else { return [:] }
    var out: [String: String] = [:]
    for (key, value) in map {
      out[key] = "\(value)"
    }
    return out
  }

  private func logState(_ step: String) {
    let item = player.currentItem
    NSLog(
      "[WAVE_IOS_MUSIC] %@ title=%@ item=%@ timeControl=%@ waiting=%@ rate=%.2f error=%@",
      step,
      currentTitle,
      statusName(item?.status),
      timeControlName(player.timeControlStatus),
      waitingReasonName(player.reasonForWaitingToPlay),
      player.rate,
      item?.error?.localizedDescription ?? player.error?.localizedDescription ?? ""
    )
  }

  private func statusName(_ status: AVPlayerItem.Status?) -> String {
    switch status {
    case .readyToPlay: return "readyToPlay"
    case .failed: return "failed"
    case .unknown: return "unknown"
    case .none: return "nil"
    @unknown default: return "other"
    }
  }

  private func timeControlName(_ status: AVPlayer.TimeControlStatus) -> String {
    switch status {
    case .paused: return "paused"
    case .waitingToPlayAtSpecifiedRate: return "waiting"
    case .playing: return "playing"
    @unknown default: return "other"
    }
  }

  private func waitingReasonName(_ reason: AVPlayer.WaitingReason?) -> String {
    guard let reason else { return "none" }
    switch reason {
    case .toMinimizeStalls: return "minimizeStalls"
    case .evaluatingBufferingRate: return "evaluatingBuffer"
    case .noItemToPlay: return "noItem"
    case .interstitialEvent: return "interstitial"
    default: return reason.rawValue
    }
  }
}

/// Forces Range requests for googlevideo progressive audio.
/// A plain GET/HEAD without Range returns HTTP 403 and AVPlayer rejects the item.
///
/// AVPlayer issues many loadingRequests over the life of a track (probe, buffer,
/// seek). Each request must honor currentOffset and return only the bytes asked for.
final class WaveYtResourceLoader: NSObject, AVAssetResourceLoaderDelegate, URLSessionTaskDelegate {
  static let scheme = "waveyt"
  /// Cap each CDN fetch so long tracks / "load to end" requests do not allocate
  /// the remainder of the file in one Data buffer. AVPlayer will ask again.
  private static let maxChunkBytes: Int64 = 2 * 1024 * 1024

  let queue = DispatchQueue(label: "wave.music.yt.loader")
  var headers: [String: String] = [:]
  var logLabel = ""

  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 20
    config.timeoutIntervalForResource = 60
    config.waitsForConnectivity = true
    config.networkServiceType = .responsiveData
    config.httpMaximumConnectionsPerHost = 4
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  private var tasks: [ObjectIdentifier: URLSessionDataTask] = [:]

  static func playbackURL(from url: URL) -> URL? {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = scheme
    return components?.url
  }

  func cancelAll() {
    queue.async { [weak self] in
      guard let self else { return }
      for task in self.tasks.values {
        task.cancel()
      }
      self.tasks.removeAll()
    }
  }

  private func httpsURL(from url: URL) -> URL? {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.scheme = "https"
    return components?.url
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
  ) -> Bool {
    guard
      let requestURL = loadingRequest.request.url,
      let realURL = httpsURL(from: requestURL)
    else {
      loadingRequest.finishLoading(with: NSError(domain: "WAVE", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Invalid resource URL",
      ]))
      return true
    }

    var request = URLRequest(url: realURL)
    request.httpMethod = "GET"
    request.cachePolicy = .reloadIgnoringLocalCacheData
    applyPlaybackHeaders(to: &request)

    let rangeHeader = rangeHeader(for: loadingRequest.dataRequest)
    request.setValue(rangeHeader, forHTTPHeaderField: "Range")

    NSLog(
      "[WAVE_IOS_MUSIC] loader request title=%@ host=%@ range=%@",
      logLabel,
      realURL.host ?? "",
      rangeHeader
    )

    let key = ObjectIdentifier(loadingRequest)
    let task = session.dataTask(with: request) { [weak self] data, response, error in
      self?.queue.async {
        self?.complete(
          loadingRequest,
          data: data,
          response: response,
          error: error,
          host: realURL.host ?? "cdn"
        )
      }
    }
    tasks[key] = task
    task.resume()
    return true
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    didCancel loadingRequest: AVAssetResourceLoadingRequest
  ) {
    let key = ObjectIdentifier(loadingRequest)
    // Already on loader.queue when set via setDelegate(_:queue:).
    tasks[key]?.cancel()
    tasks[key] = nil
  }

  /// Re-apply WAVE / YouTube Music headers after CDN redirects.
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    var redirected = request
    applyPlaybackHeaders(to: &redirected)
    if let range = task.originalRequest?.value(forHTTPHeaderField: "Range")
      ?? task.currentRequest?.value(forHTTPHeaderField: "Range") {
      redirected.setValue(range, forHTTPHeaderField: "Range")
    }
    NSLog(
      "[WAVE_IOS_MUSIC] loader redirect title=%@ host=%@ status=%d",
      logLabel,
      redirected.url?.host ?? "",
      response.statusCode
    )
    completionHandler(redirected)
  }

  private func applyPlaybackHeaders(to request: inout URLRequest) {
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
    if request.value(forHTTPHeaderField: "User-Agent") == nil {
      request.setValue(
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1",
        forHTTPHeaderField: "User-Agent"
      )
    }
    if request.value(forHTTPHeaderField: "Referer") == nil {
      request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
    }
    if request.value(forHTTPHeaderField: "Origin") == nil {
      request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
    }
    if request.value(forHTTPHeaderField: "Accept") == nil {
      request.setValue("*/*", forHTTPHeaderField: "Accept")
    }
  }

  /// Prefer currentOffset so repeated fills / seeks resume at the byte AVPlayer wants next.
  private func rangeHeader(for dataRequest: AVAssetResourceLoadingDataRequest?) -> String {
    guard let dataRequest else {
      return "bytes=0-1"
    }
    let start = max(Int64(0), dataRequest.currentOffset)
    if dataRequest.requestsAllDataToEndOfResource {
      let end = start + Self.maxChunkBytes - 1
      return "bytes=\(start)-\(end)"
    }
    let requested = Int64(max(1, dataRequest.requestedLength))
    let length = min(requested, Self.maxChunkBytes)
    let end = start + length - 1
    return "bytes=\(start)-\(end)"
  }

  private func complete(
    _ loadingRequest: AVAssetResourceLoadingRequest,
    data: Data?,
    response: URLResponse?,
    error: Error?,
    host: String
  ) {
    let key = ObjectIdentifier(loadingRequest)
    defer { tasks[key] = nil }

    // Cancelled requests must not be finished again.
    if loadingRequest.isCancelled {
      return
    }
    if let error {
      let nsError = error as NSError
      if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
        return
      }
      NSLog("[WAVE_IOS_MUSIC] loader error title=%@ host=%@ %@", logLabel, host, error.localizedDescription)
      if !loadingRequest.isCancelled {
        loadingRequest.finishLoading(with: error)
      }
      return
    }

    guard let http = response as? HTTPURLResponse else {
      loadingRequest.finishLoading(with: NSError(domain: "WAVE", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "Missing HTTP response",
      ]))
      return
    }

    let status = http.statusCode
    let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "audio/mp4"
    NSLog(
      "[WAVE_IOS_MUSIC] loader response title=%@ host=%@ status=%d type=%@ bytes=%d",
      logLabel,
      host,
      status,
      contentType,
      data?.count ?? 0
    )

    // 206 is the expected googlevideo answer; 200 is accepted if the body can be sliced.
    if status != 200 && status != 206 {
      loadingRequest.finishLoading(with: NSError(domain: "WAVE", code: status, userInfo: [
        NSLocalizedDescriptionKey: "Stream HTTP \(status) from \(host)",
      ]))
      return
    }

    if let info = loadingRequest.contentInformationRequest {
      info.contentType = uti(for: contentType)
      info.isByteRangeAccessSupported = true
      // Full resource length must come from Content-Range total on 206.
      // Content-Length on a partial response is only the chunk size.
      if let length = fullContentLength(from: http, status: status) {
        info.contentLength = length
      }
    }

    if let dataRequest = loadingRequest.dataRequest {
      let payload = bytesForDataRequest(
        dataRequest,
        data: data ?? Data(),
        response: http,
        status: status
      )
      if payload == nil {
        loadingRequest.finishLoading(with: NSError(domain: "WAVE", code: 3, userInfo: [
          NSLocalizedDescriptionKey: "Byte range mismatch from \(host)",
        ]))
        return
      }
      if let payload, !payload.isEmpty {
        dataRequest.respond(with: payload)
      }
    }

    if !loadingRequest.isCancelled {
      loadingRequest.finishLoading()
    }
  }

  /// Returns the exact bytes AVPlayer still needs, or nil on an unrecoverable gap.
  private func bytesForDataRequest(
    _ dataRequest: AVAssetResourceLoadingDataRequest,
    data: Data,
    response: HTTPURLResponse,
    status: Int
  ) -> Data? {
    if data.isEmpty { return Data() }

    let neededStart = dataRequest.currentOffset
    let responseStart: Int64
    if status == 206 {
      guard let start = contentRangeStart(from: response) else { return nil }
      responseStart = start
    } else {
      // Full-body 200: payload begins at file offset 0.
      responseStart = 0
    }

    if responseStart > neededStart {
      // CDN skipped past the byte AVPlayer is waiting for.
      return nil
    }

    let skip = Int(neededStart - responseStart)
    if skip >= data.count {
      return Data()
    }

    var payload = data.subdata(in: skip..<data.count)

    if !dataRequest.requestsAllDataToEndOfResource {
      let alreadySatisfied = Int(max(0, neededStart - dataRequest.requestedOffset))
      let remaining = dataRequest.requestedLength - alreadySatisfied
      if remaining > 0 && payload.count > remaining {
        payload = Data(payload.prefix(remaining))
      }
    }

    return payload
  }

  private func fullContentLength(from response: HTTPURLResponse, status: Int) -> Int64? {
    if let range = response.value(forHTTPHeaderField: "Content-Range"),
       let total = range.split(separator: "/").last,
       total != "*",
       let value = Int64(total),
       value > 0 {
      return value
    }
    // Only trust Content-Length as the full size on a non-partial response.
    if status == 200,
       let length = response.value(forHTTPHeaderField: "Content-Length"),
       let value = Int64(length),
       value > 0 {
      return value
    }
    return nil
  }

  private func contentRangeStart(from response: HTTPURLResponse) -> Int64? {
    guard let range = response.value(forHTTPHeaderField: "Content-Range") else { return nil }
    // Example: "bytes 1000-2047/80000"
    let trimmed = range.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.lowercased().hasPrefix("bytes") else { return nil }
    let body = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
    let startToken = body.split(separator: "-", maxSplits: 1).first
    guard let startToken, let value = Int64(startToken) else { return nil }
    return value
  }

  private func uti(for mime: String) -> String {
    let lower = mime.lowercased()
    if lower.contains("mpegurl") || lower.contains("m3u8") {
      return "public.m3u-playlist"
    }
    if lower.contains("audio/mp4") || lower.contains("m4a") {
      return AVFileType.mpeg4Audio.rawValue
    }
    if lower.contains("mpeg") && !lower.contains("mp4") {
      return "public.mp3"
    }
    return AVFileType.mpeg4Audio.rawValue
  }
}

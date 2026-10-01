import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// iOS WAVE MUSIC engine. Android keeps Media3 and is not registered here.
final class WaveMusicIosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let player = AVPlayer()
  private var eventSink: FlutterEventSink?
  private var timeObserver: Any?
  private var endObserver: NSObjectProtocol?
  private var stallObserver: NSObjectProtocol?
  private var statusObserver: NSKeyValueObservation?
  private var repeatMode = "off"
  private var commandsBound = false
  private var currentId = ""
  private var currentTitle = ""
  private var currentArtist = ""
  private var currentArtwork: String?
  private var reportedError = false

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
      playItem(items[index], play: play)
      emit("index", ["index": index, "id": currentId])
      result(nil)
    case "play":
      activateSession()
      player.play()
      emit("playing", ["playing": true])
      updateNowPlaying(rate: 1)
      result(nil)
    case "pause":
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
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
    UIApplication.shared.beginReceivingRemoteControlEvents()
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
      self?.player.play()
      self?.emit("playing", ["playing": true])
      self?.updateNowPlaying(rate: 1)
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      self?.player.pause()
      self?.emit("paused", [:])
      self?.updateNowPlaying(rate: 0)
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      if self.player.timeControlStatus == .playing {
        self.player.pause()
        self.emit("paused", [:])
        self.updateNowPlaying(rate: 0)
      } else {
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

  private func playItem(_ raw: [String: Any], play: Bool) {
    activateSession()
    bindCommands()
    let urlString = (raw["audioUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let url = URL(string: urlString), urlString.hasPrefix("http") else {
      emit("error", ["message": "This track is unavailable to stream."])
      return
    }
    currentId = raw["id"] as? String ?? ""
    currentTitle = raw["title"] as? String ?? ""
    currentArtist = raw["artist"] as? String ?? ""
    currentArtwork = raw["artworkUrl"] as? String
    reportedError = false
    let headers = stringMap(raw["headers"])
    let asset = AVURLAsset(
      url: url,
      options: headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
    )
    let item = AVPlayerItem(asset: asset)
    replaceItem(item)
    observe(item)
    if play {
      player.play()
      emit("playing", ["playing": true])
      updateNowPlaying(rate: 1)
    } else {
      emit("paused", [:])
      updateNowPlaying(rate: 0)
    }
    loadArtwork()
  }

  private func replaceItem(_ item: AVPlayerItem?) {
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
    statusObserver = nil
    player.replaceCurrentItem(with: item)
    guard item != nil else { return }
    let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      self?.emitPosition(time)
    }
  }

  private func observe(_ item: AVPlayerItem) {
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      if self.repeatMode == "one" {
        self.seek(to: 0)
        self.player.play()
        return
      }
      self.emit("ended", [:])
    }
    statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard let self, item.status == .failed, !self.reportedError else { return }
      self.reportedError = true
      self.emit("error", ["message": item.error?.localizedDescription ?? "Playback failed"])
    }
    stallObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemPlaybackStalled,
      object: item,
      queue: .main
    ) { [weak self] _ in
      self?.emit("buffering", [:])
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
}

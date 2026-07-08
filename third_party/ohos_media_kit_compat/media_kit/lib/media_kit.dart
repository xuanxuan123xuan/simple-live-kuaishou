import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String _channelName = 'simple_live/ohos_native_player';

enum MPVLogLevel { info, error }

class MediaKit {
  static void ensureInitialized() {}
}

class PlayerConfiguration {
  final String? title;
  final MPVLogLevel logLevel;

  const PlayerConfiguration({
    this.title,
    this.logLevel = MPVLogLevel.error,
  });
}

class Media {
  final String uri;
  final Map<String, String>? httpHeaders;

  const Media(this.uri, {this.httpHeaders});

  @override
  String toString() => uri;
}

class Playlist {
  final List<Media> medias;
  final int index;

  const Playlist({this.medias = const [], this.index = 0});
}

class Track {
  final Object? audio;
  final Object? video;

  const Track({this.audio, this.video});
}

class PlayerState {
  final int? width;
  final int? height;
  final double volume;
  final bool playing;
  final bool buffering;
  final bool completed;
  final Playlist playlist;
  final Track track;
  final Object? videoParams;
  final Object? audioParams;
  final double? audioBitrate;

  const PlayerState({
    this.width,
    this.height,
    this.volume = 100,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.playlist = const Playlist(),
    this.track = const Track(),
    this.videoParams,
    this.audioParams,
    this.audioBitrate,
  });

  PlayerState copyWith({
    int? width,
    int? height,
    double? volume,
    bool? playing,
    bool? buffering,
    bool? completed,
    Playlist? playlist,
    Track? track,
    Object? videoParams,
    Object? audioParams,
    double? audioBitrate,
  }) {
    return PlayerState(
      width: width ?? this.width,
      height: height ?? this.height,
      volume: volume ?? this.volume,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      completed: completed ?? this.completed,
      playlist: playlist ?? this.playlist,
      track: track ?? this.track,
      videoParams: videoParams ?? this.videoParams,
      audioParams: audioParams ?? this.audioParams,
      audioBitrate: audioBitrate ?? this.audioBitrate,
    );
  }
}

class PlayerStream {
  final StreamController<String> _error = StreamController<String>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final StreamController<String> _log = StreamController<String>.broadcast();
  final StreamController<int?> _width = StreamController<int?>.broadcast();
  final StreamController<int?> _height = StreamController<int?>.broadcast();
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();

  Stream<String> get error => _error.stream;
  Stream<bool> get playing => _playing.stream;
  Stream<bool> get completed => _completed.stream;
  Stream<String> get log => _log.stream;
  Stream<int?> get width => _width.stream;
  Stream<int?> get height => _height.stream;
  Stream<Duration> get position => _position.stream;
  Stream<bool> get buffering => _buffering.stream;

  Future<void> dispose() async {
    await Future.wait([
      _error.close(),
      _playing.close(),
      _completed.close(),
      _log.close(),
      _width.close(),
      _height.close(),
      _position.close(),
      _buffering.close(),
    ]);
  }
}

class Player {
  Player({PlayerConfiguration? configuration})
      : configuration = configuration ?? const PlayerConfiguration(),
        platform = _CompatNativePlatform() {
    _bridge.register(this);
  }

  static final _NativeBridge _bridge = _NativeBridge();

  final PlayerConfiguration configuration;
  final Object platform;
  final PlayerStream stream = PlayerStream();

  PlayerState state = const PlayerState();
  int? _viewId;
  Media? _media;
  bool _disposed = false;

  void attachNativeView(int viewId) {
    _viewId = viewId;
  }

  Future<void> open(Media media) async {
    _media = media;
    state = state.copyWith(
      playlist: Playlist(medias: [media]),
      completed: false,
      buffering: true,
    );
    stream._buffering.add(true);
    await _invoke('play', <String, dynamic>{
      'url': media.uri,
      if (media.httpHeaders != null) 'headers': media.httpHeaders,
    });
  }

  Future<void> play() async {
    final media = _media;
    if (media == null) {
      return;
    }
    await _invoke('play', <String, dynamic>{'url': media.uri});
  }

  Future<void> pause() => _invoke('pause');

  Future<void> stop() async {
    await _invoke('stop');
    state = state.copyWith(playing: false, buffering: false);
    stream._playing.add(false);
    stream._buffering.add(false);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _bridge.unregister(this);
    await _invoke('dispose');
    await stream.dispose();
  }

  Future<void> setVolume(double value) async {
    final volume = value.clamp(0.0, 100.0).toDouble();
    state = state.copyWith(volume: volume);
    await _invoke('setVolume', <String, dynamic>{'volume': volume / 100});
  }

  Future<void> seek(Duration position) => _invoke(
        'seek',
        <String, dynamic>{'position': position.inMilliseconds},
      );

  Future<Uint8List?> screenshot() async => null;

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    if (_disposed) {
      return;
    }
    await _bridge.channel.invokeMethod<void>(method, <String, dynamic>{
      if (_viewId != null) 'viewId': _viewId,
      ...?args,
    });
  }

  void _handleEvent(Map<dynamic, dynamic> event) {
    final eventViewId = (event['viewId'] as num?)?.toInt();
    if (_viewId != null && eventViewId != null && eventViewId != _viewId) {
      return;
    }
    final stateName = event['state']?.toString() ?? '';
    final progress = event['progress'];
    if (progress is Map) {
      final positionMs = (progress['position'] as num?)?.toInt() ?? 0;
      stream._position.add(Duration(milliseconds: positionMs));
    }
    if (stateName == 'playing') {
      state = state.copyWith(playing: true, buffering: false, completed: false);
      stream._playing.add(true);
      stream._buffering.add(false);
    } else if (stateName == 'paused' || stateName == 'idle') {
      state = state.copyWith(playing: false, buffering: false);
      stream._playing.add(false);
      stream._buffering.add(false);
    } else if (stateName == 'buffering' || stateName == 'preparing') {
      state = state.copyWith(buffering: true);
      stream._buffering.add(true);
    } else if (stateName == 'completed') {
      state = state.copyWith(playing: false, buffering: false, completed: true);
      stream._completed.add(true);
      stream._playing.add(false);
    } else if (stateName == 'error') {
      final message = event['message']?.toString() ?? 'OHOS native player error';
      state = state.copyWith(playing: false, buffering: false);
      stream._error.add(message);
    }
  }
}

class _CompatNativePlatform {
  Future<void> setProperty(String name, String value) async {}
}

class _NativeBridge {
  final MethodChannel channel = const MethodChannel(_channelName);
  final Set<Player> _players = <Player>{};

  _NativeBridge() {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'event' || call.arguments is! Map) {
        return;
      }
      final event = call.arguments as Map<dynamic, dynamic>;
      for (final player in List<Player>.from(_players)) {
        player._handleEvent(event);
      }
    });
  }

  void register(Player player) {
    _players.add(player);
  }

  void unregister(Player player) {
    _players.remove(player);
  }
}
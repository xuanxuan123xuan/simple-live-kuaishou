import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const String kOhosNativePlayerViewType = 'simple_live/ohos_native_player';
const String kOhosNativePlayerChannel = 'simple_live/ohos_native_player';

bool get isOhosRuntime {
  if (kIsWeb) {
    return false;
  }
  return Platform.operatingSystem == 'ohos' ||
      const bool.fromEnvironment('TARGET_OHOS');
}

enum NativePlayerPlaybackState {
  idle,
  preparing,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

class NativePlayerProgress {
  final Duration position;
  final Duration duration;
  final double buffered;

  const NativePlayerProgress({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = 0,
  });

  factory NativePlayerProgress.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const NativePlayerProgress();
    }
    return NativePlayerProgress(
      position: Duration(milliseconds: (map['position'] as num?)?.toInt() ?? 0),
      duration: Duration(milliseconds: (map['duration'] as num?)?.toInt() ?? 0),
      buffered:
          ((map['buffered'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble(),
    );
  }
}

class NativePlayerEvent {
  final NativePlayerPlaybackState state;
  final NativePlayerProgress progress;
  final String? message;

  const NativePlayerEvent({
    required this.state,
    this.progress = const NativePlayerProgress(),
    this.message,
  });

  factory NativePlayerEvent.fromMap(Map<dynamic, dynamic> map) {
    final stateName = map['state']?.toString() ?? 'idle';
    final state = NativePlayerPlaybackState.values.firstWhere(
      (item) => item.name == stateName,
      orElse: () => NativePlayerPlaybackState.idle,
    );
    return NativePlayerEvent(
      state: state,
      progress: NativePlayerProgress.fromMap(
        map['progress'] is Map
            ? map['progress'] as Map<dynamic, dynamic>
            : null,
      ),
      message: map['message']?.toString(),
    );
  }
}

abstract class SimpleLivePlayerController {
  Stream<NativePlayerEvent> get events;
  ValueListenable<NativePlayerProgress> get progress;
  ValueListenable<NativePlayerPlaybackState> get playbackState;

  Future<void> play(String url);
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<NativePlayerProgress> getProgress();
  Future<void> fullscreen();
  Future<void> exitFullscreen();
  Future<void> setVolume(double value);
  Future<void> stop();
  Future<void> dispose();
}

class OhosNativePlayerController implements SimpleLivePlayerController {
  OhosNativePlayerController({String? channelName})
      : _channel = MethodChannel(channelName ?? kOhosNativePlayerChannel) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<NativePlayerEvent> _events =
      StreamController<NativePlayerEvent>.broadcast();
  final ValueNotifier<NativePlayerProgress> _progress =
      ValueNotifier<NativePlayerProgress>(const NativePlayerProgress());
  final ValueNotifier<NativePlayerPlaybackState> _playbackState =
      ValueNotifier<NativePlayerPlaybackState>(NativePlayerPlaybackState.idle);

  int? _viewId;
  bool _disposed = false;

  @override
  Stream<NativePlayerEvent> get events => _events.stream;

  @override
  ValueListenable<NativePlayerProgress> get progress => _progress;

  @override
  ValueListenable<NativePlayerPlaybackState> get playbackState =>
      _playbackState;

  Widget buildView({BoxFit fit = BoxFit.contain}) {
    return OhosNativePlayerView(controller: this, fit: fit);
  }

  void attachView(int viewId) {
    _viewId = viewId;
  }

  @override
  Future<void> play(String url) {
    return _invoke('play', <String, dynamic>{'url': url});
  }

  @override
  Future<void> pause() {
    return _invoke('pause');
  }

  @override
  Future<void> seek(Duration position) {
    return _invoke('seek', <String, dynamic>{
      'position': position.inMilliseconds,
    });
  }

  @override
  Future<NativePlayerProgress> getProgress() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getProgress',
      _withViewId(),
    );
    final value = NativePlayerProgress.fromMap(result);
    _progress.value = value;
    return value;
  }

  @override
  Future<void> fullscreen() {
    return _invoke('fullscreen');
  }

  @override
  Future<void> exitFullscreen() {
    return _invoke('exitFullscreen');
  }

  @override
  Future<void> setVolume(double value) {
    return _invoke('setVolume', <String, dynamic>{
      'volume': value.clamp(0, 100) / 100,
    });
  }

  @override
  Future<void> stop() {
    return _invoke('stop');
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? arguments]) async {
    if (_disposed) {
      return;
    }
    await _channel.invokeMethod<void>(method, _withViewId(arguments));
  }

  Map<String, dynamic> _withViewId([Map<String, dynamic>? arguments]) {
    return <String, dynamic>{
      if (_viewId != null) 'viewId': _viewId,
      ...?arguments,
    };
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'event' || call.arguments is! Map) {
      return;
    }
    final event = NativePlayerEvent.fromMap(call.arguments as Map);
    _progress.value = event.progress;
    _playbackState.value = event.state;
    _events.add(event);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await _channel.invokeMethod<void>('dispose', _withViewId());
    _disposed = true;
    await _events.close();
    _progress.dispose();
    _playbackState.dispose();
    _channel.setMethodCallHandler(null);
  }
}

class OhosNativePlayerView extends StatelessWidget {
  final OhosNativePlayerController controller;
  final BoxFit fit;

  const OhosNativePlayerView({
    required this.controller,
    this.fit = BoxFit.contain,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOhosRuntime) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'OHOS Native Player',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return PlatformViewLink(
      viewType: kOhosNativePlayerViewType,
      surfaceFactory: (context, controller) {
        return PlatformViewSurface(
          controller: controller,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final platformViewController =
            PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: kOhosNativePlayerViewType,
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{'fit': fit.name},
          creationParamsCodec: const StandardMessageCodec(),
        );
        controller.attachView(params.id);
        platformViewController
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
        return platformViewController;
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:simple_live_app/services/native_player/native_player.dart';

class ChewieController {
  final SimpleLivePlayerController videoPlayerController;
  final bool autoPlay;
  final bool looping;
  final bool allowFullScreen;
  final bool allowMuting;
  final bool showControls;
  final double? aspectRatio;
  final Widget? placeholder;
  final Widget? overlay;
  final BoxFit fit;
  String? _lastUrl;

  ChewieController({
    required this.videoPlayerController,
    this.autoPlay = false,
    this.looping = false,
    this.allowFullScreen = true,
    this.allowMuting = true,
    this.showControls = true,
    this.aspectRatio,
    this.placeholder,
    this.overlay,
    this.fit = BoxFit.contain,
  });

  Future<void> play(String url) {
    _lastUrl = url;
    return videoPlayerController.play(url);
  }

  Future<void> resume() {
    final url = _lastUrl;
    if (url == null || url.isEmpty) {
      return Future<void>.value();
    }
    return videoPlayerController.play(url);
  }

  Future<void> pause() => videoPlayerController.pause();
  Future<void> seekTo(Duration position) => videoPlayerController.seek(position);
  Future<NativePlayerProgress> getProgress() =>
      videoPlayerController.getProgress();
  Future<void> enterFullScreen() => videoPlayerController.fullscreen();
  Future<void> exitFullScreen() => videoPlayerController.exitFullscreen();
  Future<void> dispose() => videoPlayerController.dispose();
}

class Chewie extends StatefulWidget {
  final ChewieController controller;

  const Chewie({required this.controller, super.key});

  @override
  State<Chewie> createState() => _ChewieState();
}

class _ChewieState extends State<Chewie> {
  bool _muted = false;

  SimpleLivePlayerController get _player => widget.controller.videoPlayerController;

  @override
  Widget build(BuildContext context) {
    final child = _buildNativeView();
    return AspectRatio(
      aspectRatio: widget.controller.aspectRatio ?? 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.controller.placeholder ?? const ColoredBox(color: Colors.black),
          child,
          if (widget.controller.overlay != null) widget.controller.overlay!,
          if (widget.controller.showControls) _buildControls(context),
        ],
      ),
    );
  }

  Widget _buildNativeView() {
    final controller = widget.controller.videoPlayerController;
    if (controller is OhosNativePlayerController) {
      return controller.buildView(fit: widget.controller.fit);
    }
    return const ColoredBox(color: Colors.black);
  }

  Widget _buildControls(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withAlpha(180)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ValueListenableBuilder<NativePlayerPlaybackState>(
                valueListenable: _player.playbackState,
                builder: (context, state, _) {
                  final playing = state == NativePlayerPlaybackState.playing;
                  return IconButton(
                    color: Colors.white,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: playing ? _player.pause : widget.controller.resume,
                  );
                },
              ),
              Expanded(
                child: ValueListenableBuilder<NativePlayerProgress>(
                  valueListenable: _player.progress,
                  builder: (context, progress, _) {
                    final duration = progress.duration.inMilliseconds;
                    final position = progress.position.inMilliseconds;
                    return Slider(
                      value: duration <= 0
                          ? 0
                          : position.clamp(0, duration).toDouble(),
                      max: duration <= 0 ? 1 : duration.toDouble(),
                      onChanged: duration <= 0
                          ? null
                          : (value) => _player.seek(
                                Duration(milliseconds: value.round()),
                              ),
                    );
                  },
                ),
              ),
              if (widget.controller.allowMuting)
                IconButton(
                  color: Colors.white,
                  icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                  onPressed: () async {
                    _muted = !_muted;
                    await _player.setVolume(_muted ? 0 : 100);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              if (widget.controller.allowFullScreen)
                IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _player.fullscreen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
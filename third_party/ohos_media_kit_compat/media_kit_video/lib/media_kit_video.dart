import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

const String _viewType = 'simple_live/ohos_native_player';

class NativePlayer {
  Future<void> setProperty(String name, String value) async {}
}

class VideoControllerConfiguration {
  final String? vo;
  final String? hwdec;
  final bool? enableHardwareAcceleration;
  final bool androidAttachSurfaceAfterVideoParameters;

  const VideoControllerConfiguration({
    this.vo,
    this.hwdec,
    this.enableHardwareAcceleration,
    this.androidAttachSurfaceAfterVideoParameters = false,
  });
}

class VideoController {
  final Player player;
  final VideoControllerConfiguration configuration;

  VideoController(
    this.player, {
    this.configuration = const VideoControllerConfiguration(),
  });
}

typedef VideoControlsBuilder = Widget Function(VideoState state);

Widget NoVideoControls(VideoState state) => const SizedBox.shrink();

class Video extends StatefulWidget {
  final VideoController controller;
  final VideoControlsBuilder? controls;
  final double? aspectRatio;
  final BoxFit fit;
  final bool wakelock;
  final bool pauseUponEnteringBackgroundMode;
  final bool resumeUponEnteringForegroundMode;

  const Video({
    required this.controller,
    this.controls,
    this.aspectRatio,
    this.fit = BoxFit.contain,
    this.wakelock = true,
    this.pauseUponEnteringBackgroundMode = false,
    this.resumeUponEnteringForegroundMode = false,
    super.key,
  });

  @override
  VideoState createState() => VideoState();
}

class VideoState extends State<Video> {
  @override
  Widget build(BuildContext context) {
    final video = _OhosPlatformVideo(player: widget.controller.player);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (widget.aspectRatio != null)
          Center(
            child: AspectRatio(
              aspectRatio: widget.aspectRatio!,
              child: FittedBox(fit: widget.fit, child: video),
            ),
          )
        else
          video,
        if (widget.controls != null) widget.controls!(this),
      ],
    );
  }

  void update({BoxFit? fit, double? aspectRatio}) {
    if (mounted) {
      setState(() {});
    }
  }
}

class _OhosPlatformVideo extends StatelessWidget {
  final Player player;

  const _OhosPlatformVideo({required this.player});

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) {
        return PlatformViewSurface(
          controller: controller,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final controller = PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: const <String, dynamic>{},
          creationParamsCodec: const StandardMessageCodec(),
        );
        player.attachNativeView(params.id);
        controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
        return controller;
      },
    );
  }
}
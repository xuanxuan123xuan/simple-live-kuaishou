import common from '@ohos.app.ability.common';
import { FlutterEngine, MethodCall, MethodChannel, MethodResult, StandardMethodCodec } from '@ohos/flutter_ohos';
import { OhosNativePlayerFactory } from './OhosNativePlayerView';
import { OhosNativePlayerRegistry } from './OhosNativePlayerRegistry';

const CHANNEL_NAME = 'simple_live/ohos_native_player';
const VIEW_TYPE = 'simple_live/ohos_native_player';

export class OhosNativePlayerPlugin {
  private channel?: MethodChannel;
  private registry: OhosNativePlayerRegistry = OhosNativePlayerRegistry.instance;

  constructor(private context: common.UIAbilityContext) {}

  registerWith(engine: FlutterEngine): void {
    this.channel = new MethodChannel(engine.dartExecutor, CHANNEL_NAME, StandardMethodCodec.INSTANCE);
    this.channel.setMethodCallHandler((call: MethodCall, result: MethodResult) => {
      this.onMethodCall(call, result);
    });
    const factory = new OhosNativePlayerFactory(this.context, (event) => {
      this.channel?.invokeMethod('event', event);
    });
    engine.platformViewsController.registry.registerViewFactory(VIEW_TYPE, factory);
  }

  handleBackground(): void {
    this.registry.pauseAllForBackground();
  }

  handleForeground(): void {
    this.registry.resumeForegroundPlayers();
  }

  dispose(): void {
    this.registry.disposeAll();
    this.channel?.setMethodCallHandler(null);
    this.channel = undefined;
  }

  private onMethodCall(call: MethodCall, result: MethodResult): void {
    const args = (call.arguments ?? {}) as Record<string, Object>;
    const viewId = Number(args['viewId'] ?? -1);
    const player = this.registry.find(viewId) ?? this.registry.latest();
    if (!player) {
      result.error('NO_PLAYER_VIEW', 'OHOS native player view is not ready', null);
      return;
    }

    switch (call.method) {
      case 'play':
        player.play(String(args['url'] ?? ''))
          .then(() => result.success(null))
          .catch((error: Error) => result.error('PLAY_FAILED', error.message, null));
        break;
      case 'pause':
        player.pause().then(() => result.success(null));
        break;
      case 'seek':
        player.seek(Number(args['position'] ?? 0)).then(() => result.success(null));
        break;
      case 'getProgress':
        result.success(player.progress());
        break;
      case 'fullscreen':
        player.enterFullscreen().then(() => result.success(null));
        break;
      case 'exitFullscreen':
        player.exitFullscreen().then(() => result.success(null));
        break;
      case 'setVolume':
        player.setVolume(Number(args['volume'] ?? 1)).then(() => result.success(null));
        break;
      case 'stop':
        player.stop().then(() => result.success(null));
        break;
      case 'dispose':
        player.dispose();
        result.success(null);
        break;
      default:
        result.notImplemented();
    }
  }
}
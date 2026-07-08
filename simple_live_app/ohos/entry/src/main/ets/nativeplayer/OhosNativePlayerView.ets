import common from '@ohos.app.ability.common';
import media from '@ohos.multimedia.media';
import window from '@ohos.window';
import { FrameNode, NodeController, UIContext } from '@ohos.arkui.node';
import { PlatformView, PlatformViewFactory, StandardMessageCodec } from '@ohos/flutter_ohos';
import { OhosNativePlayerRegistry } from './OhosNativePlayerRegistry';

type PlayerEventSink = (event: Record<string, Object>) => void;

@Component
struct NativeVideoSurface {
  @Prop surfaceId: string;

  build() {
    XComponent({
      id: this.surfaceId,
      type: XComponentType.SURFACE,
      libraryname: 'simple_live_player_napi'
    })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
  }
}

class NativeVideoNodeController extends NodeController {
  private node?: FrameNode;

  constructor(private uiContext: UIContext, private surfaceId: string) {
    super();
  }

  makeNode(uiContext: UIContext): FrameNode | null {
    if (!this.node) {
      this.node = new FrameNode(uiContext);
      this.node.setBuilderNode(NativeVideoSurface({ surfaceId: this.surfaceId }));
    }
    return this.node;
  }
}

export class OhosNativePlayerFactory extends PlatformViewFactory {
  constructor(private context: common.UIAbilityContext, private eventSink: PlayerEventSink) {
    super(StandardMessageCodec.INSTANCE);
  }

  create(context: common.Context, viewId: number, args: Object): PlatformView {
    const view = new OhosNativePlayerView(this.context, viewId, this.eventSink);
    OhosNativePlayerRegistry.instance.register(viewId, view);
    return view;
  }
}

export class OhosNativePlayerView implements PlatformView {
  private avPlayer?: media.AVPlayer;
  private nodeController?: NativeVideoNodeController;
  private currentUrl: string = '';
  private lastPosition: number = 0;
  private duration: number = 0;
  private buffered: number = 0;
  private playing: boolean = false;
  private prepared: boolean = false;
  private disposed: boolean = false;
  private surfaceId: string;

  constructor(
    private context: common.UIAbilityContext,
    private viewId: number,
    private eventSink: PlayerEventSink
  ) {
    this.surfaceId = `simple-live-player-${viewId}`;
  }

  getView(): NodeController {
    if (!this.nodeController) {
      this.nodeController = new NativeVideoNodeController(this.context.windowStage.getMainWindowSync().getUIContext(), this.surfaceId);
    }
    return this.nodeController;
  }

  async play(url: string): Promise<void> {
    if (!url || this.disposed) {
      return;
    }
    if (this.currentUrl !== url) {
      await this.open(url);
      return;
    }
    await this.avPlayer?.play();
  }

  async pause(): Promise<void> {
    if (!this.avPlayer || this.disposed) {
      return;
    }
    await this.avPlayer.pause();
    this.playing = false;
    this.emit('paused');
  }

  async resumeAfterForeground(): Promise<void> {
    if (!this.avPlayer || this.disposed || !this.currentUrl) {
      return;
    }
    await this.avPlayer.play();
  }

  async seek(positionMs: number): Promise<void> {
    if (!this.avPlayer || this.disposed) {
      return;
    }
    await this.avPlayer.seek(Math.max(0, positionMs));
  }

  async setVolume(volume: number): Promise<void> {
    if (!this.avPlayer || this.disposed) {
      return;
    }
    const value = Math.max(0, Math.min(1, volume));
    await this.avPlayer.setVolume(value, value);
  }

  async stop(): Promise<void> {
    if (!this.avPlayer || this.disposed) {
      return;
    }
    await this.avPlayer.stop();
    this.playing = false;
    this.prepared = false;
    this.emit('idle');
  }

  async enterFullscreen(): Promise<void> {
    const mainWindow = await this.context.windowStage.getMainWindow();
    await mainWindow.setWindowLayoutFullScreen(true);
    await mainWindow.setWindowSystemBarEnable([]);
    await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE);
  }

  async exitFullscreen(): Promise<void> {
    const mainWindow = await this.context.windowStage.getMainWindow();
    await mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION);
    await mainWindow.setWindowLayoutFullScreen(false);
    await mainWindow.setWindowSystemBarEnable(['status', 'navigation']);
  }

  isPlaying(): boolean {
    return this.playing;
  }

  progress(): Record<string, Object> {
    return {
      position: this.lastPosition,
      duration: this.duration,
      buffered: this.buffered
    };
  }

  dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    OhosNativePlayerRegistry.instance.unregister(this.viewId);
    this.avPlayer?.release();
    this.avPlayer = undefined;
    this.emit('idle');
  }

  private async open(url: string): Promise<void> {
    this.emit('preparing');
    await this.releasePlayer();
    this.currentUrl = url;
    this.avPlayer = await media.createAVPlayer();
    this.bindPlayerEvents(this.avPlayer);
    this.avPlayer.url = url;
    await this.avPlayer.prepare();
    this.prepared = true;
    await this.avPlayer.play();
  }

  private async releasePlayer(): Promise<void> {
    if (!this.avPlayer) {
      return;
    }
    try {
      await this.avPlayer.stop();
    } catch (_) {}
    await this.avPlayer.release();
    this.avPlayer = undefined;
    this.playing = false;
    this.prepared = false;
  }

  private bindPlayerEvents(player: media.AVPlayer): void {
    player.on('stateChange', (state: string) => {
      if (state === 'prepared' || state === 'initialized') {
        this.emit('ready');
      } else if (state === 'playing') {
        this.playing = true;
        this.emit('playing');
      } else if (state === 'paused') {
        this.playing = false;
        this.emit('paused');
      } else if (state === 'completed') {
        this.playing = false;
        this.emit('completed');
      } else if (state === 'stopped' || state === 'released') {
        this.playing = false;
        this.emit('idle');
      }
    });
    player.on('timeUpdate', (timeMs: number) => {
      this.lastPosition = timeMs;
      this.emit(this.playing ? 'playing' : 'paused');
    });
    player.on('durationUpdate', (durationMs: number) => {
      this.duration = durationMs;
      this.emit(this.playing ? 'playing' : 'ready');
    });
    player.on('bufferingUpdate', (infoType: number, value: number) => {
      this.buffered = Math.max(0, Math.min(1, value / 100));
      this.emit('buffering');
    });
    player.on('error', (error) => {
      this.playing = false;
      this.emit('error', `${error.code ?? ''} ${error.message ?? error}`.trim());
    });
  }

  private emit(state: string, message?: string): void {
    this.eventSink({
      viewId: this.viewId,
      state,
      progress: this.progress(),
      message: message ?? ''
    });
  }
}
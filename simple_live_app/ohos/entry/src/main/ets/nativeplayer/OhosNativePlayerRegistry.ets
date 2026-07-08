import { OhosNativePlayerView } from './OhosNativePlayerView';

export class OhosNativePlayerRegistry {
  static readonly instance: OhosNativePlayerRegistry = new OhosNativePlayerRegistry();
  private players: Map<number, OhosNativePlayerView> = new Map();
  private latestViewId: number = -1;
  private backgroundPaused: Set<number> = new Set();

  register(viewId: number, player: OhosNativePlayerView): void {
    this.players.set(viewId, player);
    this.latestViewId = viewId;
  }

  unregister(viewId: number): void {
    this.players.delete(viewId);
    this.backgroundPaused.delete(viewId);
    if (this.latestViewId === viewId) {
      this.latestViewId = -1;
    }
  }

  find(viewId: number): OhosNativePlayerView | undefined {
    return this.players.get(viewId);
  }

  latest(): OhosNativePlayerView | undefined {
    if (this.latestViewId >= 0) {
      return this.players.get(this.latestViewId);
    }
    const values = Array.from(this.players.values());
    return values.length > 0 ? values[values.length - 1] : undefined;
  }

  pauseAllForBackground(): void {
    this.players.forEach((player, viewId) => {
      if (player.isPlaying()) {
        this.backgroundPaused.add(viewId);
        player.pause();
      }
    });
  }

  resumeForegroundPlayers(): void {
    this.backgroundPaused.forEach((viewId) => {
      this.players.get(viewId)?.resumeAfterForeground();
    });
    this.backgroundPaused.clear();
  }

  disposeAll(): void {
    this.players.forEach((player) => player.dispose());
    this.players.clear();
    this.backgroundPaused.clear();
    this.latestViewId = -1;
  }
}
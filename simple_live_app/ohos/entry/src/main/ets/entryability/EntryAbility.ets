import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { OhosNativePlayerPlugin } from '../nativeplayer/OhosNativePlayerPlugin';

export default class EntryAbility extends FlutterAbility {
  private playerPlugin?: OhosNativePlayerPlugin;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    super.configureFlutterEngine(flutterEngine);
    this.playerPlugin = new OhosNativePlayerPlugin(this.context);
    this.playerPlugin.registerWith(flutterEngine);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    super.onWindowStageCreate(windowStage);
    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      mainWindow.setWindowLayoutFullScreen(false);
      mainWindow.setWindowKeepScreenOn(true);
    });
  }

  onForeground(): void {
    super.onForeground();
    this.playerPlugin?.handleForeground();
  }

  onBackground(): void {
    this.playerPlugin?.handleBackground();
    super.onBackground();
  }

  onDestroy(): void {
    this.playerPlugin?.dispose();
    this.playerPlugin = undefined;
    super.onDestroy();
  }
}
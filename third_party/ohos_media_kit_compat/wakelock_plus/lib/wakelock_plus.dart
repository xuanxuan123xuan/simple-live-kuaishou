class WakelockPlus {
  static Future<void> enable() async {}

  static Future<void> disable() async {}

  static Future<void> toggle({required bool enable}) async {}

  static Future<bool> get enabled async => false;
}

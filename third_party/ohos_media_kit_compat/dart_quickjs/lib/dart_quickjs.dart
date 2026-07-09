class JsRuntime {
  JsRuntime({int? memoryLimit, int? maxStackSize});

  dynamic eval(String code) {
    throw UnsupportedError(
      'dart_quickjs is not available on the OHOS compatibility build.',
    );
  }

  void dispose() {}
}

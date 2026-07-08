#include <hilog/log.h>
#include <napi/native_api.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x534c4956
#define LOG_TAG "SimpleLivePlayerNapi"

static napi_value Init(napi_env env, napi_value exports) {
  OH_LOG_INFO(LOG_APP, "simple_live_player_napi initialized");
  return exports;
}

static napi_module simpleLivePlayerModule = {
  .nm_version = 1,
  .nm_flags = 0,
  .nm_filename = nullptr,
  .nm_register_func = Init,
  .nm_modname = "simple_live_player_napi",
  .nm_priv = nullptr,
  .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterSimpleLivePlayerModule() {
  napi_module_register(&simpleLivePlayerModule);
}
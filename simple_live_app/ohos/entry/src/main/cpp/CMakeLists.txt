cmake_minimum_required(VERSION 3.5.0)
project(simple_live_player_napi)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

add_library(simple_live_player_napi SHARED napi_init.cpp)
target_link_libraries(simple_live_player_napi PUBLIC libace_napi.z.so libhilog_ndk.z.so)
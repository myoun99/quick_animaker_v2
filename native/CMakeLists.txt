# Compatibility shim (2A migration): the C sources now live in the plugin
# package (packages/qa_native/src) so CocoaPods, Gradle and the desktop
# runners can all reach ONE copy. The app's Windows runner still does
# `add_subdirectory(../native)` and CI still builds `-S native`, so this
# file keeps both working while the Windows path migrates last.
#
# Delete this directory once windows/CMakeLists.txt consumes the plugin.
cmake_minimum_required(VERSION 3.14)
project(qa_engine_shim LANGUAGES C)

add_subdirectory(
  "${CMAKE_CURRENT_LIST_DIR}/../packages/qa_native/src"
  "qa_native_src_build"
)

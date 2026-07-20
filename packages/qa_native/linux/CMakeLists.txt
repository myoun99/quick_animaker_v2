# The Linux side of the FFI plugin: build the shared C and tell Flutter's
# bundler to ship the resulting .so beside the app.
cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "qa_native")
project(${PROJECT_NAME} LANGUAGES C)

add_subdirectory("../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# The magic variable Flutter's Linux build reads to bundle native libs.
set(qa_native_bundled_libraries
  $<TARGET_FILE:qa_engine>
  PARENT_SCOPE
)

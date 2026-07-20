# The native core's ONE build description, shared by every consumer:
# the plugin's per-platform build files include this, and the app's
# Windows runner still reaches it through native/CMakeLists.txt while
# that migration finishes.
#
# Nothing platform-specific lives here except the compiler flags, because
# qa_engine.c is one portable C99 source by design.
cmake_minimum_required(VERSION 3.14)
project(qa_engine LANGUAGES C)

add_library(qa_engine SHARED "${CMAKE_CURRENT_LIST_DIR}/qa_engine.c")

set_target_properties(qa_engine PROPERTIES
  C_STANDARD 99
  C_STANDARD_REQUIRED ON
)

# The Wintab sidecar (pen program, PEN-2) — Windows only: talks to the
# tablet driver directly through wintab32.dll (loaded dynamically at
# runtime; building needs no vendor SDK). Same bundle-beside-the-exe +
# dart:ffi consumption pattern as qa_engine, absence = graceful.
if(WIN32)
  add_library(qa_tablet SHARED "${CMAKE_CURRENT_LIST_DIR}/qa_tablet_win.c")
  set_target_properties(qa_tablet PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
  )
endif()

if(MSVC)
  # The engine must run OPTIMIZED even inside the app's Debug build (the
  # project's performance bar is debug mode). MSVC's Debug defaults
  # (/RTC1 /Od) conflict with /O2 - strip them for this directory only.
  string(REPLACE "/RTC1" "" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
  string(REPLACE "/Od" "" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
  string(REPLACE "/Ob0" "" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
  target_compile_options(qa_engine PRIVATE /O2 /fp:precise)
else()
  # -O3 auto-vectorizes the pixel loops (SSE/AVX on x86, NEON on ARM);
  # no hand-written intrinsics needed. fp semantics stay strict so the
  # double math matches the Dart reference byte-exactly.
  target_compile_options(qa_engine PRIVATE -O3)
  find_library(QA_M_LIB m)
  if(QA_M_LIB)
    target_link_libraries(qa_engine ${QA_M_LIB})
  endif()
endif()

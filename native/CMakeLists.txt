# QuickAnimaker native engine core (R18): one portable C source,
# cross-compiled per platform. Consumed by each platform runner's build
# (windows/CMakeLists.txt adds this directory and bundles the DLL).
cmake_minimum_required(VERSION 3.14)
project(qa_engine LANGUAGES C)

add_library(qa_engine SHARED qa_engine.c)

# The Wintab sidecar (pen program, PEN-2) — Windows only: talks to the
# tablet driver directly through wintab32.dll (loaded dynamically at
# runtime; building needs no vendor SDK). Same bundle-beside-the-exe +
# dart:ffi consumption pattern as qa_engine, absence = graceful.
if(WIN32)
  add_library(qa_tablet SHARED qa_tablet_win.c)
  set_target_properties(qa_tablet PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
  )
endif()

set_target_properties(qa_engine PROPERTIES
  C_STANDARD 99
  C_STANDARD_REQUIRED ON
)

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
  target_link_libraries(qa_engine m)
endif()

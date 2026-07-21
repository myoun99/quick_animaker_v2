# The native core's ONE build description, shared by every consumer:
# the plugin's per-platform build files include this (Windows included —
# the 2A migration is complete), and CI builds it standalone for the
# parity suites.
#
# Nothing platform-specific lives here except the compiler flags, because
# qa_engine.c is one portable C99 source by design.
cmake_minimum_required(VERSION 3.14)
project(qa_engine LANGUAGES C)

# qa_audio_decode.c is a second translation unit rather than more of
# qa_engine.c: it pulls in ~27k lines of vendored dr_libs, and compiling
# that alongside the hot loops would slow every build and mix third-party
# warnings into ours.
add_library(qa_engine SHARED
  "${CMAKE_CURRENT_LIST_DIR}/qa_engine.c"
  "${CMAKE_CURRENT_LIST_DIR}/qa_audio_decode.c"
  "${CMAKE_CURRENT_LIST_DIR}/qa_audio_device.c"
)

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

# Vendored dr_libs emits a few benign conversion warnings. We do not edit
# those files (see third_party/dr_libs/PROVENANCE.md — updates must stay a
# straight overwrite), so the warnings are silenced on THIS translation
# unit only. Our own code keeps every warning it had.
if(MSVC)
  set_source_files_properties(
    "${CMAKE_CURRENT_LIST_DIR}/qa_audio_decode.c"
    "${CMAKE_CURRENT_LIST_DIR}/qa_audio_device.c"
    PROPERTIES COMPILE_OPTIONS "/wd4267;/wd4244;/wd4996;/wd4018;/wd4389")
else()
  set_source_files_properties(
    "${CMAKE_CURRENT_LIST_DIR}/qa_audio_decode.c"
    "${CMAKE_CURRENT_LIST_DIR}/qa_audio_device.c"
    PROPERTIES COMPILE_OPTIONS "-Wno-conversion;-Wno-unused-function")
endif()

# miniaudio dlopens the platform audio APIs at runtime, so building needs
# no audio dev headers — that is what keeps CI's Linux job from needing an
# ALSA package. It does need the OS threading/dl primitives, and on Apple
# the CoreAudio frameworks at LINK time.
if(APPLE)
  target_link_libraries(qa_engine
    "-framework CoreFoundation" "-framework CoreAudio" "-framework AudioToolbox")
elseif(UNIX AND NOT ANDROID)
  find_package(Threads REQUIRED)
  target_link_libraries(qa_engine Threads::Threads ${CMAKE_DL_LIBS})
elseif(ANDROID)
  target_link_libraries(qa_engine OpenSLES)
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
  # no hand-written intrinsics needed.
  #
  # -ffp-contract=off is the byte-parity contract, not a micro-tuning
  # knob: clang fuses `a*b + c` into a single FMA whenever the target has
  # one, and an FMA rounds ONCE where Dart rounds twice. On x86 that
  # never fired (no FMA in the baseline target) so five rounds of engine
  # work looked fine — the first parity run on Apple silicon came back
  # 182 where the reference says 181. Contraction stays off so the same
  # source produces the same pixels on every CPU.
  target_compile_options(qa_engine PRIVATE -O3 -ffp-contract=off)
  find_library(QA_M_LIB m)
  if(QA_M_LIB)
    target_link_libraries(qa_engine ${QA_M_LIB})
  endif()
endif()

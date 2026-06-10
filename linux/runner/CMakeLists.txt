cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES C CXX)

# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "clide_app.cc"
  "protocols/server-decoration-protocol.c"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

apply_standard_settings(${BINARY_NAME})

add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Frameless custom chrome (D-057) drives the Wayland server-decoration protocol,
# which needs wayland-client at build time. It is a HARD requirement on a Linux
# desktop build host: without it the decoration-suppression path is compiled out
# and the app silently ships the compositor's native title bar — the exact thing
# D-057 removes (double title bar on KDE Plasma Wayland). Fail the configure
# loudly rather than drop a core feature (T-349).
pkg_check_modules(WAYLAND_CLIENT IMPORTED_TARGET wayland-client)
if(NOT WAYLAND_CLIENT_FOUND)
  message(FATAL_ERROR
    "wayland-client (Wayland client dev headers) not found, but clide's "
    "frameless window chrome (D-057) requires it. Install it — Fedora: "
    "wayland-devel, Debian/Ubuntu: libwayland-dev — and rebuild.")
endif()

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)
target_compile_definitions(${BINARY_NAME} PRIVATE HAS_WAYLAND_CLIENT=1)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/runner")

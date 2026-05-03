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

# Find wayland-client for xdg-decoration protocol (D-057).
pkg_check_modules(WAYLAND_CLIENT IMPORTED_TARGET wayland-client)

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
if(WAYLAND_CLIENT_FOUND)
  target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)
  target_compile_definitions(${BINARY_NAME} PRIVATE HAS_WAYLAND_CLIENT=1)
endif()

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/runner")

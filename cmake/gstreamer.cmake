include(ExternalProject)

set(GSTREAMER_SRC_DIR ${CMAKE_SOURCE_DIR}/third_party/gstreamer CACHE PATH "Path to GStreamer source directory")

# Check if cached value exists and is valid
if(GSTREAMER_SRC_DIR AND EXISTS "${GSTREAMER_SRC_DIR}/meson.build")
    set(GSTREAMER_SRC_DIR ${GSTREAMER_SRC_DIR} CACHE PATH "Path to GStreamer source directory" FORCE)
else()
    message(FATAL_ERROR "GStreamer source directory not found at ${GSTREAMER_SRC_DIR}")
endif()

# Build directory for GStreamer
# Use source directory so it persists across build clean operations
set(GSTREAMER_BUILD_DIR ${CMAKE_SOURCE_DIR}/.gstreamer-build CACHE PATH "GStreamer build directory")
set(GSTREAMER_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/.gstreamer-install CACHE PATH "GStreamer install prefix")

# Find Meson and Ninja
find_program(MESON_EXE meson REQUIRED)
find_program(NINJA_EXE ninja REQUIRED)

# Configure Meson build options
# Enable main plugins: base, good, bad, ugly
# Disable tests, examples, and documentation for faster builds
set(GSTREAMER_MESON_OPTIONS
    --prefix=${GSTREAMER_INSTALL_PREFIX}
    -Dbase=enabled
    -Dgood=enabled
    -Dbad=enabled
    -Dugly=enabled
    -Dlibnice=enabled
    -Drtsp_server=enabled
    -Dwebrtc=enabled
    -Dlibav=enabled
    -Dges=enabled
    -Dvaapi=enabled
    -Dgpl=enabled
    -Dtests=disabled
    -Dexamples=disabled
    -Ddoc=disabled
    -Dtools=enabled
    -Ddevtools=disabled
    -Ddefault_library=shared
)

# Build type configuration
# Independent build type flag for GStreamer (defaults to Release)
set(GSTREAMER_BUILD_TYPE "Release" CACHE STRING "Build type for GStreamer (Debug or Release)")
set_property(CACHE GSTREAMER_BUILD_TYPE PROPERTY STRINGS "Debug" "Release")
# Normalize build type value
string(TOLOWER "${GSTREAMER_BUILD_TYPE}" GSTREAMER_BUILD_TYPE_LOWER)
if(GSTREAMER_BUILD_TYPE_LOWER STREQUAL "debug")
    list(APPEND GSTREAMER_MESON_OPTIONS --buildtype=debug)
else()
    list(APPEND GSTREAMER_MESON_OPTIONS --buildtype=release)
endif()

# Determine library extension and naming based on platform
if(UNIX AND NOT APPLE)
    set(GSTREAMER_LIB_EXT ".so")
    # On Linux, libraries are typically versioned (e.g., libgstreamer-1.0.so.0)
    # but we link against the unversioned symlink (libgstreamer-1.0.so)
    set(GSTREAMER_LIB_SUFFIX "")
elseif(APPLE)
    set(GSTREAMER_LIB_EXT ".dylib")
    set(GSTREAMER_LIB_SUFFIX "")
elseif(WIN32)
    set(GSTREAMER_LIB_EXT ".dll")
    set(GSTREAMER_IMPLIB_EXT ".lib")
    set(GSTREAMER_LIB_SUFFIX "-0")
endif()

# Find the GStreamer library directory (may be architecture-specific)
# Check common locations: lib/ or lib/<arch>/
# This directory may not exist at configure time if GStreamer hasn't been built yet
set(GSTREAMER_LIB_DIR "${GSTREAMER_INSTALL_PREFIX}/lib")
if(EXISTS "${GSTREAMER_INSTALL_PREFIX}/lib")
    # Check if libraries are in architecture-specific subdirectory
    file(GLOB GSTREAMER_ARCH_LIB_DIRS "${GSTREAMER_INSTALL_PREFIX}/lib/*/libgstreamer-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}")
    if(GSTREAMER_ARCH_LIB_DIRS)
        # Extract the directory from the first found library
        get_filename_component(GSTREAMER_ARCH_LIB_DIR "${GSTREAMER_ARCH_LIB_DIRS}" DIRECTORY)
        set(GSTREAMER_LIB_DIR "${GSTREAMER_ARCH_LIB_DIR}")
    endif()
endif()

# Find the GStreamer include directory (may be architecture-specific)
# Check common locations: lib/gstreamer-1.0/include or lib/<arch>/gstreamer-1.0/include
set(GSTREAMER_LIB_INCLUDE_DIR "")
if(EXISTS "${GSTREAMER_LIB_DIR}/gstreamer-1.0/include")
    set(GSTREAMER_LIB_INCLUDE_DIR "${GSTREAMER_LIB_DIR}/gstreamer-1.0/include")
endif()

# Find GLib (required dependency for GStreamer)
# GStreamer depends on GLib, so we need to find and link it
find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB REQUIRED glib-2.0)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
pkg_check_modules(GIO REQUIRED gio-2.0)

# Check if GStreamer is already configured (Meson creates build.ninja file)
set(GSTREAMER_BUILD_INFO_FILE "${GSTREAMER_BUILD_DIR}/build.ninja")
if(EXISTS "${GSTREAMER_BUILD_INFO_FILE}")
    set(GSTREAMER_CONFIGURE_CMD ${CMAKE_COMMAND} -E echo "GStreamer already configured, skipping...")
else()
    set(GSTREAMER_CONFIGURE_CMD ${MESON_EXE} setup ${GSTREAMER_BUILD_DIR} ${GSTREAMER_SRC_DIR} ${GSTREAMER_MESON_OPTIONS})
endif()

# ExternalProject to build GStreamer
ExternalProject_Add(
    gstreamer_build
    SOURCE_DIR ${GSTREAMER_SRC_DIR}
    BINARY_DIR ${GSTREAMER_BUILD_DIR}
    INSTALL_DIR ${GSTREAMER_INSTALL_PREFIX}
    CONFIGURE_COMMAND ${GSTREAMER_CONFIGURE_CMD}
    BUILD_COMMAND ${NINJA_EXE} -C ${GSTREAMER_BUILD_DIR}
    INSTALL_COMMAND ${NINJA_EXE} -C ${GSTREAMER_BUILD_DIR} install
    BUILD_ALWAYS OFF
    BUILD_BYPRODUCTS
        ${GSTREAMER_LIB_DIR}/libgstreamer-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
        ${GSTREAMER_LIB_DIR}/libgstapp-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
        ${GSTREAMER_LIB_DIR}/libgstvideo-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
        ${GSTREAMER_LIB_DIR}/libgstaudio-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)

# Create imported targets for GStreamer libraries
# These will point to the installed libraries after the build

# GStreamer core library
add_library(GStreamer::gstreamer SHARED IMPORTED)
set_target_properties(GStreamer::gstreamer PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libgstreamer-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
# Set include directories (only add lib include dir if it exists)
set(GSTREAMER_INCLUDE_DIRS_LIST ${GSTREAMER_INSTALL_PREFIX}/include/gstreamer-1.0)
if(GSTREAMER_LIB_INCLUDE_DIR)
    list(APPEND GSTREAMER_INCLUDE_DIRS_LIST ${GSTREAMER_LIB_INCLUDE_DIR})
endif()

# Create the include directory if it doesn't exist
# This is necessary because CMake validates INTERFACE_INCLUDE_DIRECTORIES at configure time
# even though the directory will be populated during the ExternalProject build
if(NOT EXISTS "${GSTREAMER_INSTALL_PREFIX}/include/gstreamer-1.0")
    file(MAKE_DIRECTORY "${GSTREAMER_INSTALL_PREFIX}/include/gstreamer-1.0")
endif()

target_include_directories(GStreamer::gstreamer INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
# Add GLib dependencies (GStreamer requires GLib, GObject, and GIO)
target_include_directories(GStreamer::gstreamer INTERFACE 
    ${GLIB_INCLUDE_DIRS}
    ${GOBJECT_INCLUDE_DIRS}
    ${GIO_INCLUDE_DIRS}
)
target_link_libraries(GStreamer::gstreamer INTERFACE 
    ${GLIB_LIBRARIES} 
    ${GOBJECT_LIBRARIES} 
    ${GIO_LIBRARIES}
)
target_compile_options(GStreamer::gstreamer INTERFACE 
    ${GLIB_CFLAGS_OTHER}
    ${GOBJECT_CFLAGS_OTHER}
    ${GIO_CFLAGS_OTHER}
)
add_dependencies(GStreamer::gstreamer gstreamer_build)

# GStreamer App library
add_library(GStreamer::app SHARED IMPORTED)
set_target_properties(GStreamer::app PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libgstapp-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::app INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::app INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::app gstreamer_build)

# GStreamer Video library
add_library(GStreamer::video SHARED IMPORTED)
set_target_properties(GStreamer::video PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libgstvideo-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::video INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::video INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::video gstreamer_build)

# GStreamer Audio library
add_library(GStreamer::audio SHARED IMPORTED)
set_target_properties(GStreamer::audio PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libgstaudio-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::audio INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::audio INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::audio gstreamer_build)

# GStreamer RTSP library
add_library(GStreamer::rtsp SHARED IMPORTED)
set_target_properties(GStreamer::rtsp PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libgstrtsp-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::rtsp INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::rtsp INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::rtsp gstreamer_build)

# GStreamer RTSP Server library
add_library(GStreamer::rtsp-server SHARED IMPORTED)
set_target_properties(GStreamer::rtsp-server PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libgstrtspserver-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::rtsp-server INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::rtsp-server INTERFACE 
    GStreamer::gstreamer
    GStreamer::rtsp
)
add_dependencies(GStreamer::rtsp-server gstreamer_build)

# GStreamer Libnice library
add_library(GStreamer::libnice SHARED IMPORTED)
set_target_properties(GStreamer::libnice PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libnice${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::libnice INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::libnice INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::libnice gstreamer_build)

# GStreamer WebRTC library
add_library(GStreamer::webrtc SHARED IMPORTED)
set_target_properties(GStreamer::webrtc PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libgstwebrtc-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::webrtc INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::webrtc INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::webrtc gstreamer_build)

# GStreamer libav library
add_library(GStreamer::libav SHARED IMPORTED)
set_target_properties(GStreamer::libav PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libavtp${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::libav INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::libav INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::libav gstreamer_build)

# GStreamer GES library
add_library(GStreamer::ges SHARED IMPORTED)
set_target_properties(GStreamer::ges PROPERTIES
    IMPORTED_LOCATION ${GSTREAMER_LIB_DIR}/libges-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
)
target_include_directories(GStreamer::ges INTERFACE ${GSTREAMER_INCLUDE_DIRS_LIST})
target_link_libraries(GStreamer::ges INTERFACE GStreamer::gstreamer)
add_dependencies(GStreamer::ges gstreamer_build)


# Convenience target that includes all GStreamer components
add_library(GStreamer::gstreamer-all INTERFACE IMPORTED)
target_link_libraries(GStreamer::gstreamer-all INTERFACE
    GStreamer::gstreamer
    GStreamer::app
    GStreamer::video
    GStreamer::audio
    GStreamer::rtsp
    GStreamer::rtsp-server
    GStreamer::libnice
    GStreamer::webrtc
    GStreamer::libav
    GStreamer::ges
)

# Set environment variable for runtime (plugins path)
set(GSTREAMER_PLUGIN_PATH "${GSTREAMER_LIB_DIR}/gstreamer-1.0")
set(ENV{GST_PLUGIN_PATH} "${GSTREAMER_PLUGIN_PATH}")

# Export variables for use in other CMake files
set(GSTREAMER_FOUND TRUE CACHE BOOL "GStreamer found")
set(GSTREAMER_INCLUDE_DIRS ${GSTREAMER_INCLUDE_DIRS_LIST} CACHE PATH "GStreamer include directories")
set(GSTREAMER_LIBRARY_DIRS "${GSTREAMER_LIB_DIR}" CACHE PATH "GStreamer library directories")
set(GSTREAMER_PLUGIN_PATH "${GSTREAMER_PLUGIN_PATH}" CACHE PATH "GStreamer plugin path")

message(STATUS "GStreamer will be built from: ${GSTREAMER_SRC_DIR}")
message(STATUS "GStreamer build directory: ${GSTREAMER_BUILD_DIR}")
message(STATUS "GStreamer install prefix: ${GSTREAMER_INSTALL_PREFIX}")
message(STATUS "GStreamer build type: ${GSTREAMER_BUILD_TYPE}")
message(STATUS "GStreamer plugins enabled: base, good, bad, ugly")
message(STATUS "GStreamer plugin path: ${GSTREAMER_PLUGIN_PATH}")


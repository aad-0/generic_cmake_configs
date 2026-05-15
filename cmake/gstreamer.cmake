# Paths and options (always set; used for both building and using existing install)
set(GSTREAMER_SRC_DIR ${CMAKE_SOURCE_DIR}/third_party/gstreamer CACHE PATH "Path to GStreamer source directory")
set(GSTREAMER_BUILD_DIR ${CMAKE_SOURCE_DIR}/.gstreamer-build CACHE PATH "GStreamer build directory")
set(GSTREAMER_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/.gstreamer-install CACHE PATH "GStreamer install prefix")

if(BUILD_THIRDPARTY)
    include(ExternalProject)
    if(NOT GSTREAMER_SRC_DIR OR NOT EXISTS "${GSTREAMER_SRC_DIR}/meson.build")
        message(FATAL_ERROR "GStreamer source directory not found at ${GSTREAMER_SRC_DIR}")
    endif()
    find_program(MESON_EXE meson REQUIRED)
    find_program(NINJA_EXE ninja REQUIRED)
endif()

set(GSTREAMER_BUILD_TYPE "Release" CACHE STRING "Build type for GStreamer (Debug or Release)")
set_property(CACHE GSTREAMER_BUILD_TYPE PROPERTY STRINGS "Debug" "Release")

if(BUILD_THIRDPARTY)
    string(TOLOWER "${GSTREAMER_BUILD_TYPE}" GSTREAMER_BUILD_TYPE_LOWER)
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
        -Dgst-plugins-bad:va=enabled
        -Dgst-plugins-good:soup-version=3
        -Dlibnice:gupnp=disabled
        -Dgpl=enabled
        -Dtests=disabled
        -Dexamples=disabled
        -Ddoc=disabled
        -Dtools=enabled
        -Ddevtools=disabled
        -Ddefault_library=shared
    )
    if(GSTREAMER_BUILD_TYPE_LOWER STREQUAL "debug")
        list(APPEND GSTREAMER_MESON_OPTIONS --buildtype=debug)
    else()
        list(APPEND GSTREAMER_MESON_OPTIONS --buildtype=release)
    endif()
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

# GLib/GObject/GIO required for GStreamer target (include dirs and link libs)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB REQUIRED glib-2.0)
pkg_check_modules(GOBJECT REQUIRED gobject-2.0)
pkg_check_modules(GIO REQUIRED gio-2.0)

if(BUILD_THIRDPARTY)
    set(GSTREAMER_BUILD_INFO_FILE "${GSTREAMER_BUILD_DIR}/build.ninja")
    if(EXISTS "${GSTREAMER_BUILD_INFO_FILE}")
        set(GSTREAMER_CONFIGURE_CMD ${CMAKE_COMMAND} -E echo "GStreamer already configured, skipping...")
    else()
        set(GSTREAMER_CONFIGURE_CMD ${MESON_EXE} setup ${GSTREAMER_BUILD_DIR} ${GSTREAMER_SRC_DIR} ${GSTREAMER_MESON_OPTIONS})
    endif()
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
endif()

# Single imported target: GStreamer::gstreamer-all links all GStreamer libs and GLib
set(GSTREAMER_INCLUDE_DIRS_LIST ${GSTREAMER_INSTALL_PREFIX}/include/gstreamer-1.0)
if(GSTREAMER_LIB_INCLUDE_DIR)
    list(APPEND GSTREAMER_INCLUDE_DIRS_LIST ${GSTREAMER_LIB_INCLUDE_DIR})
endif()

if(BUILD_THIRDPARTY)
    if(NOT EXISTS "${GSTREAMER_INSTALL_PREFIX}/include/gstreamer-1.0")
        file(MAKE_DIRECTORY "${GSTREAMER_INSTALL_PREFIX}/include/gstreamer-1.0")
    endif()
endif()

# Core library must be first on the link line so the linker resolves gst_* symbols
set(GSTREAMER_CORE_LIB "${GSTREAMER_LIB_DIR}/libgstreamer-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}")
file(GLOB GSTREAMER_INSTALL_LIBS "${GSTREAMER_LIB_DIR}/lib*${GSTREAMER_LIB_EXT}")
if(GSTREAMER_INSTALL_LIBS)
    # Put core first; remove it from glob list to avoid duplicate
    list(REMOVE_ITEM GSTREAMER_INSTALL_LIBS "${GSTREAMER_CORE_LIB}")
    set(GSTREAMER_ALL_LIBS "${GSTREAMER_CORE_LIB}" ${GSTREAMER_INSTALL_LIBS})
else()
    # Fallback when lib dir missing at configure time (e.g. before building thirdparties).
    # Minimum set so gst_* symbols resolve; more libs discovered at reconfigure.
    set(GSTREAMER_ALL_LIBS
        ${GSTREAMER_CORE_LIB}
        ${GSTREAMER_LIB_DIR}/libgstbase-1.0${GSTREAMER_LIB_SUFFIX}${GSTREAMER_LIB_EXT}
    )
endif()
list(APPEND GSTREAMER_ALL_LIBS ${GLIB_LIBRARIES} ${GOBJECT_LIBRARIES} ${GIO_LIBRARIES})

add_library(GStreamer::gstreamer-all INTERFACE IMPORTED)
target_include_directories(GStreamer::gstreamer-all INTERFACE
    ${GSTREAMER_INCLUDE_DIRS_LIST}
    ${GLIB_INCLUDE_DIRS}
    ${GOBJECT_INCLUDE_DIRS}
    ${GIO_INCLUDE_DIRS}
)
target_link_libraries(GStreamer::gstreamer-all INTERFACE ${GSTREAMER_ALL_LIBS})
target_compile_options(GStreamer::gstreamer-all INTERFACE
    ${GLIB_CFLAGS_OTHER}
    ${GOBJECT_CFLAGS_OTHER}
    ${GIO_CFLAGS_OTHER}
)
if(BUILD_THIRDPARTY)
    add_dependencies(GStreamer::gstreamer-all gstreamer_build)
endif()

# Set environment variable for runtime (plugins path)
set(GSTREAMER_PLUGIN_PATH "${GSTREAMER_LIB_DIR}/gstreamer-1.0")
set(ENV{GST_PLUGIN_PATH} "${GSTREAMER_PLUGIN_PATH}")

# Export variables for use in other CMake files
set(GSTREAMER_FOUND TRUE CACHE BOOL "GStreamer found")
set(GSTREAMER_INCLUDE_DIRS ${GSTREAMER_INCLUDE_DIRS_LIST} CACHE PATH "GStreamer include directories")
set(GSTREAMER_LIBRARY_DIRS "${GSTREAMER_LIB_DIR}" CACHE PATH "GStreamer library directories")
set(GSTREAMER_PLUGIN_PATH "${GSTREAMER_PLUGIN_PATH}" CACHE PATH "GStreamer plugin path")

if(BUILD_THIRDPARTY)
    message(STATUS "GStreamer will be built from: ${GSTREAMER_SRC_DIR}")
    message(STATUS "GStreamer build directory: ${GSTREAMER_BUILD_DIR}")
else()
    message(STATUS "GStreamer: using existing install (BUILD_THIRDPARTY=OFF)")
endif()
message(STATUS "GStreamer install prefix: ${GSTREAMER_INSTALL_PREFIX}")
message(STATUS "GStreamer plugin path: ${GSTREAMER_PLUGIN_PATH}")


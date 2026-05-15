# Paths and options (always set; used for both building and using existing install)
set(SPDLOG_SRC_DIR ${CMAKE_SOURCE_DIR}/third_party/spdlog CACHE PATH "Path to spdlog source directory")
set(SPDLOG_BUILD_DIR ${CMAKE_SOURCE_DIR}/.spdlog-build CACHE PATH "spdlog build directory")
set(SPDLOG_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/.spdlog-install CACHE PATH "spdlog install prefix")
set(SPDLOG_BUILD_TYPE "Release" CACHE STRING "Build type for spdlog (Debug or Release)")
set_property(CACHE SPDLOG_BUILD_TYPE PROPERTY STRINGS "Debug" "Release")

if(BUILD_THIRDPARTY)
    include(ExternalProject)
    if(NOT SPDLOG_SRC_DIR OR NOT EXISTS "${SPDLOG_SRC_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "spdlog source directory not found at ${SPDLOG_SRC_DIR}")
    endif()
    find_program(CMAKE_EXE cmake REQUIRED)
    set(SPDLOG_CMAKE_ARGS
        -DCMAKE_BUILD_TYPE:STRING=${SPDLOG_BUILD_TYPE}
        -DCMAKE_INSTALL_PREFIX:STRING=${SPDLOG_INSTALL_PREFIX}
        -DSPDLOG_BUILD_EXAMPLES:BOOL=OFF
        -DSPDLOG_BUILD_TESTS:BOOL=OFF
        -DSPDLOG_BUILD_BENCH:BOOL=OFF
    )
endif()

# Determine library extension and naming based on platform
if(UNIX AND NOT APPLE)
    set(SPDLOG_LIB_EXT ".so")
    set(SPDLOG_LIB_SUFFIX "")
elseif(APPLE)
    set(SPDLOG_LIB_EXT ".dylib")
    set(SPDLOG_LIB_SUFFIX "")
elseif(WIN32)
    set(SPDLOG_LIB_EXT ".dll")
    set(SPDLOG_IMPLIB_EXT ".lib")
    set(SPDLOG_LIB_SUFFIX "")
endif()

# Find the spdlog library directory
# This directory may not exist at configure time if spdlog hasn't been built yet
set(SPDLOG_LIB_DIR "${SPDLOG_INSTALL_PREFIX}/lib")
if(EXISTS "${SPDLOG_INSTALL_PREFIX}/lib")
    # Check if libraries are in architecture-specific subdirectory
    file(GLOB SPDLOG_ARCH_LIB_DIRS "${SPDLOG_INSTALL_PREFIX}/lib/*/libspdlog${SPDLOG_LIB_SUFFIX}${SPDLOG_LIB_EXT}")
    if(SPDLOG_ARCH_LIB_DIRS)
        # Extract the directory from the first found library
        get_filename_component(SPDLOG_ARCH_LIB_DIR "${SPDLOG_ARCH_LIB_DIRS}" DIRECTORY)
        set(SPDLOG_LIB_DIR "${SPDLOG_ARCH_LIB_DIR}")
    endif()
endif()

# Find the spdlog include directory
set(SPDLOG_INCLUDE_DIR "${SPDLOG_INSTALL_PREFIX}/include")

if(BUILD_THIRDPARTY)
    if(NOT EXISTS "${SPDLOG_INCLUDE_DIR}")
        file(MAKE_DIRECTORY "${SPDLOG_INCLUDE_DIR}")
    endif()
    set(SPDLOG_CMAKE_CACHE "${SPDLOG_BUILD_DIR}/CMakeCache.txt")
    if(EXISTS "${SPDLOG_CMAKE_CACHE}")
        set(SPDLOG_CONFIGURE_CMD ${CMAKE_COMMAND} -E echo "spdlog already configured, skipping...")
    else()
        set(SPDLOG_CONFIGURE_CMD ${CMAKE_EXE} -S ${SPDLOG_SRC_DIR} -B ${SPDLOG_BUILD_DIR} ${SPDLOG_CMAKE_ARGS})
    endif()
    ExternalProject_Add(
        spdlog_build
        SOURCE_DIR ${SPDLOG_SRC_DIR}
        BINARY_DIR ${SPDLOG_BUILD_DIR}
        INSTALL_DIR ${SPDLOG_INSTALL_PREFIX}
        CONFIGURE_COMMAND ${SPDLOG_CONFIGURE_CMD}
        BUILD_COMMAND ${CMAKE_EXE} --build ${SPDLOG_BUILD_DIR} --config ${SPDLOG_BUILD_TYPE}
        INSTALL_COMMAND ${CMAKE_EXE} --install ${SPDLOG_BUILD_DIR} --config ${SPDLOG_BUILD_TYPE} --prefix ${SPDLOG_INSTALL_PREFIX}
        BUILD_ALWAYS OFF
        BUILD_BYPRODUCTS
            ${SPDLOG_LIB_DIR}/libspdlog${SPDLOG_LIB_SUFFIX}${SPDLOG_LIB_EXT}
    )
endif()

# Create imported targets for spdlog library (always; used for both build and use-existing-install)
if(EXISTS "${SPDLOG_LIB_DIR}/libspdlog${SPDLOG_LIB_SUFFIX}${SPDLOG_LIB_EXT}")
    add_library(spdlog::spdlog SHARED IMPORTED)
    set_target_properties(spdlog::spdlog PROPERTIES
        IMPORTED_LOCATION ${SPDLOG_LIB_DIR}/libspdlog${SPDLOG_LIB_SUFFIX}${SPDLOG_LIB_EXT}
    )
    target_include_directories(spdlog::spdlog INTERFACE ${SPDLOG_INCLUDE_DIR})
    if(BUILD_THIRDPARTY)
        add_dependencies(spdlog::spdlog spdlog_build)
    endif()
else()
    add_library(spdlog::spdlog INTERFACE IMPORTED)
    target_include_directories(spdlog::spdlog INTERFACE ${SPDLOG_INCLUDE_DIR})
    if(BUILD_THIRDPARTY)
        add_dependencies(spdlog::spdlog spdlog_build)
    endif()
endif()

# Export variables for use in other CMake files
set(SPDLOG_FOUND TRUE CACHE BOOL "spdlog found")
set(SPDLOG_INCLUDE_DIRS ${SPDLOG_INCLUDE_DIR} CACHE PATH "spdlog include directories")
set(SPDLOG_LIBRARY_DIRS "${SPDLOG_LIB_DIR}" CACHE PATH "spdlog library directories")

if(BUILD_THIRDPARTY)
    message(STATUS "spdlog will be built from: ${SPDLOG_SRC_DIR}")
else()
    message(STATUS "spdlog: using existing install (BUILD_THIRDPARTY=OFF)")
endif()
message(STATUS "spdlog install prefix: ${SPDLOG_INSTALL_PREFIX}")
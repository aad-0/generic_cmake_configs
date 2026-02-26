include(ExternalProject)

set(OPENCV_SRC_DIR ${CMAKE_SOURCE_DIR}/third_party/cv/opencv CACHE PATH "Path to OpenCV source directory")

# Check if cached value exists and is valid
if(OPENCV_SRC_DIR AND EXISTS "${OPENCV_SRC_DIR}/CMakeLists.txt")
    set(OPENCV_SRC_DIR ${OPENCV_SRC_DIR} CACHE PATH "Path to OpenCV source directory" FORCE)
else()
    message(FATAL_ERROR "OpenCV source directory not found at ${OPENCV_SRC_DIR}")
endif()

# Build directory for OpenCV
# Use source directory so it persists across build clean operations
set(OPENCV_BUILD_DIR ${CMAKE_SOURCE_DIR}/.opencv-build CACHE PATH "OpenCV build directory")
set(OPENCV_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/.opencv-install CACHE PATH "OpenCV install prefix")

# Find CMake (required for building OpenCV)
find_program(CMAKE_EXE cmake REQUIRED)

# Independent build type flag for OpenCV (defaults to Release)
set(OPENCV_BUILD_TYPE "Release" CACHE STRING "Build type for OpenCV (Debug or Release)")
set_property(CACHE OPENCV_BUILD_TYPE PROPERTY STRINGS "Debug" "Release")

# CPU baseline configuration (default to native optimization)
set(CPU_BASELINE "NATIVE" CACHE STRING "OpenCV CPU baseline optimization")
set_property(CACHE CPU_BASELINE PROPERTY STRINGS "NATIVE" "AVX2" "AVX" "SSE4_2" "SSE4_1" "SSE3" "SSE2")

# Check for opencv_contrib modules
set(OPENCV_CONTRIB_DIR ${CMAKE_SOURCE_DIR}/third_party/cv/opencv_contrib)
set(OPENCV_EXTRA_MODULES_PATH "")
if(EXISTS "${OPENCV_CONTRIB_DIR}/modules")
    set(OPENCV_EXTRA_MODULES_PATH "${OPENCV_CONTRIB_DIR}/modules")
    message(STATUS "OpenCV contrib modules found at: ${OPENCV_EXTRA_MODULES_PATH}")
endif()

# Build the list of CMake configure arguments
set(OPENCV_CMAKE_ARGS
    -DCMAKE_BUILD_TYPE:STRING=${OPENCV_BUILD_TYPE}
    -DCMAKE_INSTALL_PREFIX:STRING=${OPENCV_INSTALL_PREFIX}
    -DCPU_BASELINE:STRING=${CPU_BASELINE}
    #-DWITH_TBB:BOOL=ON
    -DWITH_PTHREADS_PF:BOOL=ON
    -DWITH_V4L:BOOL=ON
    -DWITH_QT:BOOL=OFF
    -DENABLE_FAST_MATH:BOOL=ON
    -DOPENCV_IPP_GAUSSIAN_BLUR:BOOL=ON
    -DOPENCV_IPP_MEAN:BOOL=ON
    -DOPENCV_IPP_MINMAX:BOOL=ON
    -DOPENCV_IPP_SUM:BOOL=ON
    -DWITH_GSTREAMER:BOOL=ON
    -DWITH_OPENCL:BOOL=ON
    -DOPENCV_ENABLE_NONFREE:BOOL=ON
    -DBUILD_SHARED_LIBS:BOOL=ON
    -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON
    -DBUILD_TESTS:BOOL=OFF
    -DBUILD_PERF_TESTS:BOOL=OFF
    -DBUILD_EXAMPLES:BOOL=OFF
    -DBUILD_opencv_apps:BOOL=OFF
    -DBUILD_DOCS:BOOL=OFF
    -DBUILD_JAVA:BOOL=OFF
    -DBUILD_FAT_JAVA_LIB:BOOL=OFF
    -DBUILD_opencv_python3:BOOL=OFF
    -DBUILD_opencv_python2:BOOL=OFF
    -DBUILD_opencv_python:BOOL=OFF
    -DINSTALL_PYTHON_EXAMPLES:BOOL=OFF
    -DINSTALL_C_EXAMPLES:BOOL=OFF
)

# Add opencv_contrib modules path if available
if(OPENCV_EXTRA_MODULES_PATH)
    list(APPEND OPENCV_CMAKE_ARGS -DOPENCV_EXTRA_MODULES_PATH:STRING=${OPENCV_EXTRA_MODULES_PATH})
endif()

# Determine library extension and naming based on platform
if(UNIX AND NOT APPLE)
    set(OPENCV_LIB_EXT ".so")
    set(OPENCV_LIB_SUFFIX "")
elseif(APPLE)
    set(OPENCV_LIB_EXT ".dylib")
    set(OPENCV_LIB_SUFFIX "")
elseif(WIN32)
    set(OPENCV_LIB_EXT ".dll")
    set(OPENCV_IMPLIB_EXT ".lib")
    set(OPENCV_LIB_SUFFIX "")
endif()

# Find the OpenCV library directory (may be architecture-specific)
# Check common locations: lib/ or lib/<arch>/
# This directory may not exist at configure time if OpenCV hasn't been built yet
set(OPENCV_LIB_DIR "${OPENCV_INSTALL_PREFIX}/lib")
if(EXISTS "${OPENCV_INSTALL_PREFIX}/lib")
    # Check if libraries are in architecture-specific subdirectory
    file(GLOB OPENCV_ARCH_LIB_DIRS "${OPENCV_INSTALL_PREFIX}/lib/*/libopencv_core${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}")
    if(OPENCV_ARCH_LIB_DIRS)
        # Extract the directory from the first found library
        get_filename_component(OPENCV_ARCH_LIB_DIR "${OPENCV_ARCH_LIB_DIRS}" DIRECTORY)
        set(OPENCV_LIB_DIR "${OPENCV_ARCH_LIB_DIR}")
    endif()
endif()

# Find the OpenCV include directory
# OpenCV 4.x uses include/opencv4/opencv2/
set(OPENCV_INCLUDE_DIR "${OPENCV_INSTALL_PREFIX}/include/opencv4")
if(NOT EXISTS "${OPENCV_INCLUDE_DIR}")
    # Fallback to include/opencv2/ for older versions
    set(OPENCV_INCLUDE_DIR "${OPENCV_INSTALL_PREFIX}/include")
endif()

# Create the include directory if it doesn't exist
# This is necessary because CMake validates INTERFACE_INCLUDE_DIRECTORIES at configure time
# even though the directory will be populated during the ExternalProject build
if(NOT EXISTS "${OPENCV_INCLUDE_DIR}")
    file(MAKE_DIRECTORY "${OPENCV_INCLUDE_DIR}")
endif()

# Check if OpenCV is already configured
set(OPENCV_CMAKE_CACHE "${OPENCV_BUILD_DIR}/CMakeCache.txt")
if(EXISTS "${OPENCV_CMAKE_CACHE}")
    set(OPENCV_CONFIGURE_CMD ${CMAKE_COMMAND} -E echo "OpenCV already configured, skipping...")
else()
    set(OPENCV_CONFIGURE_CMD ${CMAKE_EXE} -S ${OPENCV_SRC_DIR} -B ${OPENCV_BUILD_DIR} ${OPENCV_CMAKE_ARGS})
endif()

# ExternalProject to build OpenCV
ExternalProject_Add(
    opencv_build
    SOURCE_DIR ${OPENCV_SRC_DIR}
    BINARY_DIR ${OPENCV_BUILD_DIR}
    INSTALL_DIR ${OPENCV_INSTALL_PREFIX}
    CONFIGURE_COMMAND ${OPENCV_CONFIGURE_CMD}
    BUILD_COMMAND ${CMAKE_EXE} --build ${OPENCV_BUILD_DIR} --config ${OPENCV_BUILD_TYPE}
    INSTALL_COMMAND ${CMAKE_EXE} --install ${OPENCV_BUILD_DIR} --config ${OPENCV_BUILD_TYPE} --prefix ${OPENCV_INSTALL_PREFIX}
    BUILD_ALWAYS OFF
    BUILD_BYPRODUCTS
        ${OPENCV_LIB_DIR}/libopencv_core${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
        ${OPENCV_LIB_DIR}/libopencv_imgproc${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
        ${OPENCV_LIB_DIR}/libopencv_imgcodecs${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
        ${OPENCV_LIB_DIR}/libopencv_videoio${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
        ${OPENCV_LIB_DIR}/libopencv_highgui${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
)

# Create imported targets for OpenCV libraries
# These will point to the installed libraries after the build

# OpenCV core library
add_library(OpenCV::core SHARED IMPORTED)
set_target_properties(OpenCV::core PROPERTIES
    IMPORTED_LOCATION ${OPENCV_LIB_DIR}/libopencv_core${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
)
target_include_directories(OpenCV::core INTERFACE ${OPENCV_INCLUDE_DIR})
add_dependencies(OpenCV::core opencv_build)

# OpenCV imgproc library
add_library(OpenCV::imgproc SHARED IMPORTED)
set_target_properties(OpenCV::imgproc PROPERTIES
    IMPORTED_LOCATION ${OPENCV_LIB_DIR}/libopencv_imgproc${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
)
target_include_directories(OpenCV::imgproc INTERFACE ${OPENCV_INCLUDE_DIR})
target_link_libraries(OpenCV::imgproc INTERFACE OpenCV::core)
add_dependencies(OpenCV::imgproc opencv_build)

# OpenCV imgcodecs library
add_library(OpenCV::imgcodecs SHARED IMPORTED)
set_target_properties(OpenCV::imgcodecs PROPERTIES
    IMPORTED_LOCATION ${OPENCV_LIB_DIR}/libopencv_imgcodecs${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
)
target_include_directories(OpenCV::imgcodecs INTERFACE ${OPENCV_INCLUDE_DIR})
target_link_libraries(OpenCV::imgcodecs INTERFACE OpenCV::core)
add_dependencies(OpenCV::imgcodecs opencv_build)

# OpenCV videoio library
add_library(OpenCV::videoio SHARED IMPORTED)
set_target_properties(OpenCV::videoio PROPERTIES
    IMPORTED_LOCATION ${OPENCV_LIB_DIR}/libopencv_videoio${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
)
target_include_directories(OpenCV::videoio INTERFACE ${OPENCV_INCLUDE_DIR})
target_link_libraries(OpenCV::videoio INTERFACE OpenCV::core)
add_dependencies(OpenCV::videoio opencv_build)

# OpenCV highgui library
add_library(OpenCV::highgui SHARED IMPORTED)
set_target_properties(OpenCV::highgui PROPERTIES
    IMPORTED_LOCATION ${OPENCV_LIB_DIR}/libopencv_highgui${OPENCV_LIB_SUFFIX}${OPENCV_LIB_EXT}
)
target_include_directories(OpenCV::highgui INTERFACE ${OPENCV_INCLUDE_DIR})
target_link_libraries(OpenCV::highgui INTERFACE OpenCV::core)
add_dependencies(OpenCV::highgui opencv_build)

# Convenience target that includes all core OpenCV libraries
add_library(OpenCV::opencv INTERFACE IMPORTED)
target_link_libraries(OpenCV::opencv INTERFACE
    OpenCV::core
    OpenCV::imgproc
    OpenCV::imgcodecs
    OpenCV::videoio
    OpenCV::highgui
)
# Ensure OpenCV is built before any target using OpenCV::opencv compiles
add_dependencies(OpenCV::opencv opencv_build)

# Create lowercase alias to match CMakeLists.txt usage
add_library(opencv::opencv ALIAS OpenCV::opencv)

# Export variables for use in other CMake files
set(OPENCV_FOUND TRUE CACHE BOOL "OpenCV found")
set(OPENCV_INCLUDE_DIRS ${OPENCV_INCLUDE_DIR} CACHE PATH "OpenCV include directories")
set(OPENCV_LIBRARY_DIRS "${OPENCV_LIB_DIR}" CACHE PATH "OpenCV library directories")

message(STATUS "OpenCV will be built from: ${OPENCV_SRC_DIR}")
message(STATUS "OpenCV build directory: ${OPENCV_BUILD_DIR}")
message(STATUS "OpenCV install prefix: ${OPENCV_INSTALL_PREFIX}")
message(STATUS "OpenCV build type: ${OPENCV_BUILD_TYPE}")
message(STATUS "OpenCV CPU baseline: ${CPU_BASELINE}")
if(OPENCV_EXTRA_MODULES_PATH)
    message(STATUS "OpenCV contrib modules: enabled")
endif()

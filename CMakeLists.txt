cmake_minimum_required(VERSION 3.10)
project(CudaWatermark LANGUAGES CXX CUDA)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(OpenCV REQUIRED)
find_package(OpenSSL REQUIRED)

# Include directories
include_directories(${OpenCV_INCLUDE_DIRS})
include_directories(${OPENSSL_INCLUDE_DIR})

# Modern CMake way - use add_executable instead of cuda_add_executable
add_executable(watermark
    main.cpp
    watermark.cu
)

# Set CUDA architectures (modern way)
set_property(TARGET watermark PROPERTY CUDA_ARCHITECTURES 50)

# Link libraries
target_link_libraries(watermark
    ${OpenCV_LIBS}
    ${OPENSSL_LIBRARIES}
)
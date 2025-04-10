cmake_minimum_required(VERSION 3.10)
project(CudaWatermark LANGUAGES CXX CUDA)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(CUDA REQUIRED)
find_package(OpenCV REQUIRED)
find_package(OpenSSL REQUIRED)

# Include directories
include_directories(${CUDA_INCLUDE_DIRS})
include_directories(${OpenCV_INCLUDE_DIRS})
include_directories(${OPENSSL_INCLUDE_DIR})

# Add the executable
cuda_add_executable(watermark
    main.cpp
    watermark.cpp
)

# Link libraries
target_link_libraries(watermark
    ${OpenCV_LIBS}
    ${OPENSSL_LIBRARIES}
    ${CUDA_LIBRARIES}
)

# Cuda compiler flags
set(CUDA_NVCC_FLAGS ${CUDA_NVCC_FLAGS};-gencode arch=compute_50,code=sm_50)
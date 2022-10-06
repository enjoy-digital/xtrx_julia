cmake_minimum_required(VERSION 3.17)
project(SoapySDRXTRX CXX C)


########################################################################
## LitePCIe discovery
########################################################################

find_path(LITEPCIE_KERNEL_INCLUDE_DIR litepcie.h
          REQUIRED
          HINTS
            ${CMAKE_CURRENT_SOURCE_DIR}/../..
          PATH_SUFFIXES
            software/litepcie-kernel-module)
find_path(LITEPCIE_USER_INCLUDE_DIR liblitepcie.h
          REQUIRED
          HINTS
            ${CMAKE_CURRENT_SOURCE_DIR}/../..
          PATH_SUFFIXES
            software/litepcie-user-library/liblitepcie)
set(LITEPCIE_INCLUDE_DIR ${LITEPCIE_KERNEL_INCLUDE_DIR} ${LITEPCIE_USER_INCLUDE_DIR})
find_library(LITEPCIE_LIBRARY litepcie
             REQUIRED
             HINTS
               ${CMAKE_CURRENT_SOURCE_DIR}/../..
             PATH_SUFFIXES
               software/litepcie-user-library/liblitepcie)

include_directories(${LITEPCIE_INCLUDE_DIR})


########################################################################
## LMS7002M discovery
########################################################################

message(STATUS "Looking for LMS7002M in ${LMS7002M_ROOT}...")

find_path(LMS7002M_INCLUDE_DIR LMS7002M/LMS7002M.h
          HINTS ${LMS7002M_ROOT}
          PATH_SUFFIXES include
          REQUIRED)

find_library(LMS7002M_LIBRARY LMS7002M
             HINTS ${LMS7002M_ROOT}
             PATH_SUFFIXES lib
             REQUIRED)

include_directories(${LMS7002M_INCLUDE_DIR})


########################################################################
## CUDA discovery
########################################################################

find_package(CUDAToolkit REQUIRED)

include_directories(${CUDAToolkit_INCLUDE_DIRS})


########################################################################
## Test executable
########################################################################

add_executable(main main.c)

target_link_libraries(main ${LITEPCIE_LIBRARY} ${LMS7002M_LIBRARY} CUDA::cuda_driver m)


########################################################################
## SoapySDR library
########################################################################

find_package(SoapySDR "0.2.1" REQUIRED)

SOAPY_SDR_MODULE_UTIL(
    TARGET SoapyXTRX
    SOURCES XTRXDevice.cpp Streaming.cpp i2c0.cpp i2c1.cpp
    LIBRARIES ${LITEPCIE_LIBRARY} ${LMS7002M_LIBRARY} CUDA::cuda_driver m
)


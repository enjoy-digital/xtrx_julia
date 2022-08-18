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

include(ExternalProject)

set(EXTERNAL_INSTALL_LOCATION ${CMAKE_BINARY_DIR}/external)

ExternalProject_Add(LMS7002M-driver
     SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../LMS7002M-driver
     CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${EXTERNAL_INSTALL_LOCATION}
)

include_directories(${EXTERNAL_INSTALL_LOCATION}/include)

link_directories(${EXTERNAL_INSTALL_LOCATION}/lib)


########################################################################
## CUDA discovery
########################################################################

find_package(CUDAToolkit REQUIRED)

include_directories(${CUDAToolkit_INCLUDE_DIRS})


########################################################################
## Test executable
########################################################################

add_executable(main main.c)

target_link_libraries(main ${LITEPCIE_LIBRARY} CUDA::cuda_driver LMS7002M m)

add_dependencies(main LMS7002M-driver)


########################################################################
## SoapySDR library
########################################################################

find_package(SoapySDR "0.2.1" REQUIRED)

SOAPY_SDR_MODULE_UTIL(
    TARGET SoapyXTRX
    SOURCES XTRXDevice.cpp Streaming.cpp
    LIBRARIES ${LITEPCIE_LIBRARY} CUDA::cuda_driver LMS7002M m
)

add_dependencies(SoapyXTRX LMS7002M-driver)

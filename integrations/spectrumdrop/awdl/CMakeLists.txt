cmake_minimum_required(VERSION 3.5)

project(owl)

if (CMAKE_C_COMPILER_ID MATCHES "GNU" OR CMAKE_C_COMPILER_ID MATCHES "Clang")
    # Las uniones compartidas entre C y C++ requieren desactivar el aliasing estricto con LTO.
    add_compile_options("-Wall" "-Wextra" "-fno-strict-aliasing")
endif ()

add_library(radiotap radiotap/radiotap.c)
target_compile_definitions(radiotap PRIVATE -D_BSD_SOURCE -D_DEFAULT_SOURCE -DRADIOTAP_SUPPORT_OVERRIDES)

add_subdirectory(src)

add_subdirectory(daemon)

include(CTest)
if(BUILD_TESTING)
    find_package(GTest REQUIRED)
    add_subdirectory(tests)
endif()

file (MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/_rut/rut-bin")
if (NOT TARGET "rut-bin")
  project("rut-bin")
  add_library("rut-bin" INTERFACE)
  target_include_directories("rut-bin" INTERFACE "${CMAKE_BINARY_DIR}/_rut/")
endif()

message("-- rut > Loaded!")

function (RUTLoadCPM)
  # SPDX-License-Identifier: MIT
  #
  # SPDX-FileCopyrightText: Copyright (c) 2019-2023 Lars Melchior and contributors

  set(CPM_DOWNLOAD_VERSION 0.40.2)
  set(CPM_HASH_SUM "c8cdc32c03816538ce22781ed72964dc864b2a34a310d3b7104812a5ca2d835d")

  if(CPM_SOURCE_CACHE)
    set(CPM_DOWNLOAD_LOCATION "${CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
  elseif(DEFINED ENV{CPM_SOURCE_CACHE})
    set(CPM_DOWNLOAD_LOCATION "$ENV{CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
  else()
    set(CPM_DOWNLOAD_LOCATION "${CMAKE_BINARY_DIR}/cmake/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
  endif()

  # Expand relative path. This is important if the provided path contains a tilde (~)
  get_filename_component(CPM_DOWNLOAD_LOCATION ${CPM_DOWNLOAD_LOCATION} ABSOLUTE)

  file(DOWNLOAD
       https://github.com/cpm-cmake/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake
       ${CPM_DOWNLOAD_LOCATION} EXPECTED_HASH SHA256=${CPM_HASH_SUM}
  )

  include(${CPM_DOWNLOAD_LOCATION})
endfunction()

function (RUTSetupBuildType default)
  set(_DEFAULT_BUILD_TYPE "${default}")
  if (NOT CMAKE_BUILD_TYPE)
    message(WARNING "-- rut > No build type provided. Defaulting to '${_DEFAULT_BUILD_TYPE}'")
  else()
    set(_DEFAULT_BUILD_TYPE "${CMAKE_BUILD_TYPE}")
  endif()
  set(CMAKE_BUILD_TYPE "${_DEFAULT_BUILD_TYPE}" CACHE STRING "Options: Debug, Release, RelWithDebInfo, MinSizeRel" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
  message("-- rut > Setup build type: ${CMAKE_BUILD_TYPE}")
endfunction()

function (RUTAssertBuildType)
  if (NOT CMAKE_BUILD_TYPE)
    message(FATAL_ERROR "-- rut > ASSERT > No CMAKE_BUILD_TYPE!")
  endif()

  if (NOT ${CMAKE_BUILD_TYPE} STREQUAL "Debug"          AND
      NOT ${CMAKE_BUILD_TYPE} STREQUAL "Release"        AND
      NOT ${CMAKE_BUILD_TYPE} STREQUAL "RelWithDebInfo" AND
      NOT ${CMAKE_BUILD_TYPE} STREQUAL "MinSizeRel")
    message(FATAL_ERROR "-- rut > ASSERT > Unexpected CMAKE_BUILD_TYPE value! (${CMAKE_BUILD_TYPE})")
  endif()
endfunction()

function (RUTTargetPedantic target)
  target_compile_options(${target}
    PRIVATE
      $<$<OR:$<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:GNU>,$<C_COMPILER_ID:Clang>,$<C_COMPILER_ID:GNU>>: -Wall -Wextra -Wpedantic -Werror -Wsign-conversion>
      $<$<OR:$<CXX_COMPILER_ID:MSVC>,$<C_COMPILER_ID:MSVC>>: /W4 /WX>
  )
endfunction()

function (RUTTargetNoExcept target)
  target_compile_options(${target}
    PRIVATE
      $<$<OR:$<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:GNU>,$<C_COMPILER_ID:Clang>,$<C_COMPILER_ID:GNU>>: -fno-exceptions>
      $<$<OR:$<CXX_COMPILER_ID:MSVC>,$<C_COMPILER_ID:MSVC>>:>
  )
endfunction()

function (RUTTargetNoRTTI target)
  target_compile_options(${target}
    PRIVATE
      $<$<OR:$<CXX_COMPILER_ID:Clang>,$<CXX_COMPILER_ID:GNU>>: -fno-rtti>
      $<$<CXX_COMPILER_ID:MSVC>:>
  )
endfunction()

function (RUTTargetBuildName target fname fext)
  set_target_properties(${target} PROPERTIES
    PREFIX              ""
    SUFFIX              "${fext}"
    OUTPUT_NAME         "${fname}"
    LIBRARY_OUTPUT_NAME "${fname}"
  )
endfunction()

function (RUTTargetBuildDir target dir)
  set_target_properties(${target} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY  "${dir}"
    LIBRARY_OUTPUT_DIRECTORY  "${dir}"
  )
endfunction()

function (RUTAutoTarget target)
  cmake_parse_arguments(
    PARSE_ARGV 1
    RUT
    ""
    ""
    "SOURCES;INCLUDE;LINK_PUBLIC;LINK_PRIVATE"
  )

  set(_STATIC "${target}-static")
  add_library("${_STATIC}" STATIC ${RUT_SOURCES})
  target_include_directories("${_STATIC}" PUBLIC ${RUT_INCLUDE})
  target_link_libraries("${_STATIC}"
    PUBLIC ${RUT_LINK_PUBLIC}
    PRIVATE ${RUT_LINK_PRIVATE}
  )
  RUTTargetPedantic("${_STATIC}")

  set(_SHARED "${target}-shared")
  add_library("${_SHARED}" SHARED ${RUT_SOURCES})
  target_include_directories("${_SHARED}" PUBLIC ${RUT_INCLUDE})
  target_link_libraries("${_SHARED}"
    PUBLIC ${RUT_LINK_PUBLIC}
    PRIVATE ${RUT_LINK_PRIVATE}
  )
  RUTTargetPedantic("${_SHARED}")
endfunction()

function (RUTPackage target ldir cpm_opt)
  if (NOT TARGET ${target})
    message("-- rut > Target '${target}' not found. Trying by dir.")
    if (NOT EXISTS ${ldir})
      message("-- rut > Target '${target}' directory not found. Trying by CPM.")
      CPMAddPackage(${cpm_opt})
    else()
      message("-- rut > Target '${target}' directory found.")
      add_subdirectory("${ldir}" "${CMAKE_BINARY_DIR}/${target}")
    endif()
  else()
    message("-- rut > Target '${target}' found.")
  endif()
endfunction()

function (RUTGenBin2HeaderCpp name file)
  message("-- rut > Generating binary header file for ${file} as ${name}...")
  file(READ ${file} file_hex HEX)
  string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," file_hex ${file_hex})
  set(file_hex "namespace rut::bin{constexpr unsigned char ${name}[]={${file_hex}}\;}")
  file(WRITE "${CMAKE_BINARY_DIR}/_rut/rut-bin/${name}.hh" ${file_hex})
endfunction()

function (RUTGenBin2HeaderC name file)
  message("-- rut > Generating binary header file for ${file} as ${name}...")
  file(READ ${file} file_hex HEX)
  string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," file_hex ${file_hex})
  set(file_hex "const unsigned char ${name}[]={${file_hex}}\;")
  file(WRITE "${CMAKE_BINARY_DIR}/_rut/rut-bin/${name}.h" ${file_hex})
endfunction()

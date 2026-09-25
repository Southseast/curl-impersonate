cmake_minimum_required(VERSION 3.20)

foreach(_required ARCHIVE WORK_DIR COMPILER)
  if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
    message(FATAL_ERROR "${_required} is required")
  endif()
endforeach()

# Query only the extracted package, including a path that requires shell escaping.
set(_release "${WORK_DIR}/release with spaces")
if(EXISTS "${_release}")
  message(FATAL_ERROR "Use a fresh WORK_DIR: ${WORK_DIR}")
endif()
file(MAKE_DIRECTORY "${_release}")
file(ARCHIVE_EXTRACT INPUT "${ARCHIVE}" DESTINATION "${_release}")
find_program(PKG_CONFIG pkg-config REQUIRED)
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env
    "PKG_CONFIG_PATH=" "PKG_CONFIG_LIBDIR=${_release}" "PKG_CONFIG_SYSROOT_DIR="
    "${PKG_CONFIG}" --static --cflags --libs libcurl-impersonate
  OUTPUT_VARIABLE _flags
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
  TIMEOUT 30
)
separate_arguments(_flags UNIX_COMMAND "${_flags}")
# --static includes private dependencies but does not force ld to choose the .a.
list(REMOVE_ITEM _flags "-lcurl-impersonate")
separate_arguments(_compiler UNIX_COMMAND "${COMPILER}")
set(_program "${WORK_DIR}/static-pkgconfig")
execute_process(
  COMMAND ${_compiler} "${CMAKE_CURRENT_LIST_DIR}/../tests/static-pkgconfig.c"
    "-Wl,-force_load,${_release}/libcurl-impersonate.a" ${_flags} -o "${_program}"
  COMMAND_ERROR_IS_FATAL ANY
  TIMEOUT 120
)

set(_payload "pkg-config static consumer\n")
set(_input "${WORK_DIR}/input.txt")
file(WRITE "${_input}" "${_payload}")
string(REPLACE "%" "%25" _url "${_input}")
string(REPLACE " " "%20" _url "${_url}")
string(REPLACE "#" "%23" _url "${_url}")
string(REPLACE "?" "%3F" _url "${_url}")
execute_process(
  COMMAND "${_program}" "file://${_url}"
  OUTPUT_VARIABLE _actual
  COMMAND_ERROR_IS_FATAL ANY
  TIMEOUT 30
)
if(NOT _actual STREQUAL _payload)
  message(FATAL_ERROR "Static consumer returned incorrect file contents")
endif()

find_program(OTOOL otool REQUIRED)
execute_process(
  COMMAND "${OTOOL}" -L "${_program}"
  OUTPUT_VARIABLE _dependencies
  COMMAND_ERROR_IS_FATAL ANY
)
if(_dependencies MATCHES "libcurl-impersonate[^\n]*\\.dylib")
  message(FATAL_ERROR "Static consumer unexpectedly linked libcurl-impersonate.dylib")
endif()
message(STATUS "Relocated release: static linking and file transfer passed")

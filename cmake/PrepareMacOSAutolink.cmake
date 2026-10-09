cmake_minimum_required(VERSION 3.20)

foreach(_required LIBRARY OUTPUT)
  if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
    message(FATAL_ERROR "${_required} is required")
  endif()
endforeach()

find_program(OTOOL otool REQUIRED)
execute_process(
  COMMAND "${OTOOL}" -D "${LIBRARY}"
  OUTPUT_VARIABLE _install_names
  COMMAND_ERROR_IS_FATAL ANY
)
execute_process(
  COMMAND "${OTOOL}" -L "${LIBRARY}"
  OUTPUT_VARIABLE _dependencies
  COMMAND_ERROR_IS_FATAL ANY
)
string(REPLACE "\n" ";" _install_names "${_install_names}")
string(REPLACE "\n" ";" _dependencies "${_dependencies}")
set(_options)
foreach(_line IN LISTS _dependencies)
  if(NOT _line MATCHES "^[ \t]+(.+) \\(compatibility version [^,]+, current version [^)]+\\)$")
    continue()
  endif()
  set(_dependency "${CMAKE_MATCH_1}")
  if(_dependency IN_LIST _install_names)
    continue()
  elseif(_dependency MATCHES "^/System/Library/Frameworks/([A-Za-z0-9_]+)\\.framework/")
    list(APPEND _options "  .linker_option \"-framework\", \"${CMAKE_MATCH_1}\"")
  elseif(_dependency MATCHES "^/usr/lib/lib([A-Za-z0-9_.+-]+)\\.dylib$")
    list(APPEND _options "  .linker_option \"-l${CMAKE_MATCH_1}\"")
  else()
    message(FATAL_ERROR "Non-system dependency in ${LIBRARY}: ${_dependency}")
  endif()
endforeach()
if(NOT _options)
  message(FATAL_ERROR "No system dependencies found in ${LIBRARY}")
endif()
list(JOIN _options "\n" _options)
file(WRITE "${OUTPUT}" ".section __TEXT,__text\n${_options}\n")
message(STATUS "Generated macOS automatic link options from ${LIBRARY}")

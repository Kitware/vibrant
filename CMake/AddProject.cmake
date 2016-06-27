

include(CMakeParseArguments)

#
# Get standard library prefix and extensions
#

if(WIN32)
  set(lib_ext "lib")
  set(lib_pre "")
elseif(APPLE)
  set(lib_ext "dylib")
  set(lib_pre "lib")
else()
  set(lib_ext "so")
  set(lib_pre "lib")
endif()

#
# Set flags environment variable from default or project-specific
#
# Sets the value of the variable <name>_<cvar>. The value is either drawn from
# an existing variable <name>_<cvar>, an environment variable <name>_<evar> or
# the default bootstrap project variable CMAKE_<cvar>.
#
macro(set_flags_for_project name evar cvar)
  if(NOT "#${${name}_${cvar}}" STREQUAL "#")
    set(${name}_${cvar} "${${name}_${cvar}}")
  elseif(NOT "#$ENV{${name}_${evar}}" STREQUAL "#")
    set(${name}_${cvar} "$ENV{${name}_${evar}}")
  else()
    set(${name}_${cvar} "${CMAKE_${cvar}}")
  endif()
endmacro()

#
# Set cache arguments to propagate flags
#
# Encapsulates flags currently set on the bootstrap into variables to be passed
# into a sub-project. Custom flags may be set by defining a variable of the name
# "<name>_<flags>" or by setting and environment variable "<name>_<env>".
#
macro(set_flags_cache_args ovar name flags env)
  set_flags_for_project(${name} ${env} ${flags})
  # TODO allow per-project overrides of per-configuration flags?
  list(APPEND ${ovar}
    "-DCMAKE_${flags}:STRING=${${name}_${flags}}"
    "-DCMAKE_${flags}_DEBUG:STRING=${CMAKE_${flags}_DEBUG}"
    "-DCMAKE_${flags}_MINSIZEREL:STRING=${CMAKE_${flags}_MINSIZEREL}"
    "-DCMAKE_${flags}_RELEASE:STRING=${CMAKE_${flags}_RELEASE}"
    "-DCMAKE_${flags}_RELWITHDEBINFO:STRING=${CMAKE_${flags}_RELWITHDEBINFO}"
    )
endmacro()

#
# Write a file that may be used as an initial cache file for a project
#
# We expect one or more arguments after the file-path to write to. These
# arguments should be -D arguments as would be given to CMake on the command
# line.
#
function(write_injection injection_file_path)
  file(WRITE ${injection_file_path} "# This is an injectable file\n")
  foreach(element ${ARGN})
    string(REGEX MATCH "-D[a-zA-Z0-9_-]*:" var_name ${element})
    string(REGEX REPLACE "^-D" "" var_name ${var_name})
    string(REGEX REPLACE ":$" "" var_name ${var_name})

    string(REGEX MATCH ":.*=" var_type ${element})
    string(REGEX REPLACE "^:" "" var_type ${var_type})
    string(REGEX REPLACE "=$" "" var_type ${var_type})

    string(REGEX MATCH "=.*$" var_val ${element})
    string(REGEX REPLACE "^=" "" var_val ${var_val})
    if (var_val MATCHES "^[ \n]*$")
      set(var_val "")
    endif()

    file(APPEND ${injection_file_path} "# " ${element} "\n")
    file(APPEND ${injection_file_path} "set(" ${var_name} " " \"${var_val}\" " CACHE ${var_type} \"\" )\n")
  endforeach()
endfunction()

#
# Add a git based project
#
# Usage:
#   add_project(name git_url git_tag
#               [DEPENDS other_project_1 [other_project_2 ... ] ]
#               )
#
# Where name is the name of the project being added (ExternalProject_Add name),
# git_url is the URL address where we can draw the source repository from, and
# git_tag is the branch, tag or hash to initialize the repository to.
#
# By default, the flags variables defined on the bootstrap project are passed
# down into the added project, including build-type specific flags. General
# flags may be overridden by setting a variable of the name <name>_<flag_var>,
# where <flag_var> is something like "CXX_FLAGS" or "SHARED_LINKER_FLAGS" (note
# the lack of the "CMAKE_" prefix). It may be wise to include existing
# CMAKE_<flag_var> values if defining an <name>_<flag_var> variable unless it
# is intended to ignore top-level CMAKE_<flags_var> values.
#
# The following variables are added to the cache:
#   <name>_BINARY
#   <name>_SOURCE
#
function(add_project name git_url git_tag)
  set(cpa_options)  # None yet
  set(cpa_oneValueArgs)  # None yet
  set(cpa_multiValueArgs DEPENDS)
  cmake_parse_arguments(_ap "${cpa_options}" "${cpa_oneValueArgs}" "${cpa_multiValueArgs}" ${ARGN})

  # encapsulate flag propagation
  set(extra_cache_args)
  set_flags_cache_args(extra_cache_args ${name} CXX_FLAGS           CXXFLAGS)
  set_flags_cache_args(extra_cache_args ${name} C_FLAGS             CFLAGS)
  set_flags_cache_args(extra_cache_args ${name} STATIC_LINKER_FLAGS ARFLAGS)
  set_flags_cache_args(extra_cache_args ${name} SHARED_LINKER_FLAGS LDFLAGS)
  set_flags_cache_args(extra_cache_args ${name} MODULE_LINKER_FLAGS LDFLAGS)
  set_flags_cache_args(extra_cache_args ${name} EXE_LINKER_FLAGS    LDFLAGS)

  set(SOURCE_ROOT "${vidtk_all_BINARY_DIR}/Sources")
  set(BINARY_ROOT "${vidtk_all_BINARY_DIR}/Builds")
  set(${name}_SOURCE  "${SOURCE_ROOT}/${name}" CACHE PATH "PATH to source of ${name}")
  set(${name}_BINARY  "${BINARY_ROOT}/${name}" CACHE PATH "PATH to source of ${name}")
  set(${name}_GIT_BRANCH "${git_tag}" CACHE STRING "Git hash to checkout")
  string(TOUPPER "${name}" name_upper)
  if(NOT ${name_upper}_CTEST_BUILD_NAME)
    set(${name_upper}_CTEST_BUILD_NAME "${BUILDNAME}")
  endif()

  set(EA_CMAKE_CACHE_ARGS
    "-DBUILD_SHARED_LIBS:BOOL=${BUILD_SHARED_LIBS}"
    "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}"
    "-DBUILDNAME:STRING=${${name_upper}_CTEST_BUILD_NAME}"
    "-DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}"
    "-DCMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}"
    "-DCMAKE_LINKER:FILEPATH=${CMAKE_LINKER}"
    )

  # Determine if we are to using GIT or a Tarball as our source
  find_file(
    "${name}_DL_FILE" "${name}.tgz"
    PATHS "${vidtk_all_SOURCE_DIR}" )
  if (EXISTS "${${name}_DL_FILE}")
    set(DL_CMD "${${name}_DL_FILE}")
    set(DL_KEYWORD "URL")
  else()
    set(DL_CMD "${git_url}")
    set(DL_KEYWORD "GIT_REPOSITORY")
  endif()

  write_injection(
    ${vidtk_all_BINARY_DIR}/${name}_inject.cmake
    ${EA_CMAKE_CACHE_ARGS}
    ${extra_cache_args}
    ${_ap_UNPARSED_ARGUMENTS}
    )

  # Using input and generated cache arguments instead of injection file to
  # prevent need for aditional name input. Injection file is still generated
  # and valid.
  ExternalProject_Add(${name}
    "${DL_KEYWORD}" "${DL_CMD}"
    GIT_TAG "${${name}_GIT_BRANCH}"
    SOURCE_DIR "${${name}_SOURCE}"
    BINARY_DIR "${${name}_BINARY}"
    INSTALL_COMMAND ""
    CMAKE_ARGS
     -C "${vidtk_all_BINARY_DIR}/${name}_inject.cmake"
    )
  if (NOT "${_ap_DEPENDS}" STREQUAL "")
    add_dependencies(${name} ${_ap_DEPENDS})
  endif()
  set(${name}_BINARY_DIR "${${name}_BINARY}" PARENT_SCOPE)
  set(${name}_SOURCE_DIR "${${name}_SOURCE}" PARENT_SCOPE)
endfunction()



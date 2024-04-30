include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(GLVEX_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(GLVEX_setup_options)
  option(GLVEX_ENABLE_HARDENING "Enable hardening" ON)
  option(GLVEX_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    GLVEX_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    GLVEX_ENABLE_HARDENING
    OFF)

  GLVEX_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR GLVEX_PACKAGING_MAINTAINER_MODE)
    option(GLVEX_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(GLVEX_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(GLVEX_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(GLVEX_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(GLVEX_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(GLVEX_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(GLVEX_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(GLVEX_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(GLVEX_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(GLVEX_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(GLVEX_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(GLVEX_ENABLE_PCH "Enable precompiled headers" OFF)
    option(GLVEX_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(GLVEX_ENABLE_IPO "Enable IPO/LTO" ON)
    option(GLVEX_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(GLVEX_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(GLVEX_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(GLVEX_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(GLVEX_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(GLVEX_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(GLVEX_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(GLVEX_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(GLVEX_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(GLVEX_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(GLVEX_ENABLE_PCH "Enable precompiled headers" OFF)
    option(GLVEX_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      GLVEX_ENABLE_IPO
      GLVEX_WARNINGS_AS_ERRORS
      GLVEX_ENABLE_USER_LINKER
      GLVEX_ENABLE_SANITIZER_ADDRESS
      GLVEX_ENABLE_SANITIZER_LEAK
      GLVEX_ENABLE_SANITIZER_UNDEFINED
      GLVEX_ENABLE_SANITIZER_THREAD
      GLVEX_ENABLE_SANITIZER_MEMORY
      GLVEX_ENABLE_UNITY_BUILD
      GLVEX_ENABLE_CLANG_TIDY
      GLVEX_ENABLE_CPPCHECK
      GLVEX_ENABLE_COVERAGE
      GLVEX_ENABLE_PCH
      GLVEX_ENABLE_CACHE)
  endif()

  GLVEX_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (GLVEX_ENABLE_SANITIZER_ADDRESS OR GLVEX_ENABLE_SANITIZER_THREAD OR GLVEX_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(GLVEX_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(GLVEX_global_options)
  if(GLVEX_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    GLVEX_enable_ipo()
  endif()

  GLVEX_supports_sanitizers()

  if(GLVEX_ENABLE_HARDENING AND GLVEX_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR GLVEX_ENABLE_SANITIZER_UNDEFINED
       OR GLVEX_ENABLE_SANITIZER_ADDRESS
       OR GLVEX_ENABLE_SANITIZER_THREAD
       OR GLVEX_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${GLVEX_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${GLVEX_ENABLE_SANITIZER_UNDEFINED}")
    GLVEX_enable_hardening(GLVEX_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(GLVEX_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(GLVEX_warnings INTERFACE)
  add_library(GLVEX_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  GLVEX_set_project_warnings(
    GLVEX_warnings
    ${GLVEX_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(GLVEX_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    GLVEX_configure_linker(GLVEX_options)
  endif()

  include(cmake/Sanitizers.cmake)
  GLVEX_enable_sanitizers(
    GLVEX_options
    ${GLVEX_ENABLE_SANITIZER_ADDRESS}
    ${GLVEX_ENABLE_SANITIZER_LEAK}
    ${GLVEX_ENABLE_SANITIZER_UNDEFINED}
    ${GLVEX_ENABLE_SANITIZER_THREAD}
    ${GLVEX_ENABLE_SANITIZER_MEMORY})

  set_target_properties(GLVEX_options PROPERTIES UNITY_BUILD ${GLVEX_ENABLE_UNITY_BUILD})

  if(GLVEX_ENABLE_PCH)
    target_precompile_headers(
      GLVEX_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(GLVEX_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    GLVEX_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(GLVEX_ENABLE_CLANG_TIDY)
    GLVEX_enable_clang_tidy(GLVEX_options ${GLVEX_WARNINGS_AS_ERRORS})
  endif()

  if(GLVEX_ENABLE_CPPCHECK)
    GLVEX_enable_cppcheck(${GLVEX_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(GLVEX_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    GLVEX_enable_coverage(GLVEX_options)
  endif()

  if(GLVEX_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(GLVEX_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(GLVEX_ENABLE_HARDENING AND NOT GLVEX_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR GLVEX_ENABLE_SANITIZER_UNDEFINED
       OR GLVEX_ENABLE_SANITIZER_ADDRESS
       OR GLVEX_ENABLE_SANITIZER_THREAD
       OR GLVEX_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    GLVEX_enable_hardening(GLVEX_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()

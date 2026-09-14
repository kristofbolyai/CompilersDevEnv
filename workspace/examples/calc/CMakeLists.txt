# CMake build for the example, provided mainly for CLion: its C++ support is
# built around CMake, so opening this folder gives you completion, navigation
# and a working debugger without extra setup.
#
# The Makefile next to this file builds exactly the same program and is the
# lighter option from a terminal. Either is fine - pick one.

cmake_minimum_required(VERSION 3.7)
project(calc CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_compile_options(-Wall -Wextra)

find_program(BISONCPP_EXECUTABLE bisonc++ REQUIRED)
find_program(FLEXCPP_EXECUTABLE  flexc++  REQUIRED)

# Both generators write their output into the directory they are run from, so
# they run in the source directory and their products are listed as generated.
add_custom_command(
    OUTPUT  ${CMAKE_CURRENT_SOURCE_DIR}/parse.cc
            ${CMAKE_CURRENT_SOURCE_DIR}/parserbase.h
    COMMAND ${BISONCPP_EXECUTABLE} grammar
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/grammar
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "bisonc++: grammar -> parse.cc, parserbase.h"
)

# flexc++ needs parserbase.h first: the scanner's actions use the token
# constants that bisonc++ defines there.
add_custom_command(
    OUTPUT  ${CMAKE_CURRENT_SOURCE_DIR}/lex.cc
            ${CMAKE_CURRENT_SOURCE_DIR}/scannerbase.h
    COMMAND ${FLEXCPP_EXECUTABLE} lexer
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/lexer
            ${CMAKE_CURRENT_SOURCE_DIR}/parserbase.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "flexc++: lexer -> lex.cc, scannerbase.h"
)

add_executable(calc
    main.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/parse.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/lex.cc
)
target_include_directories(calc PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

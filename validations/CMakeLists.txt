# Author: Ming Zhang
# Copyright (c) 2021

set(WROKLOAD_SOURCES micro.cc)

add_library(valid STATIC ${WROKLOAD_SOURCES})

set_target_properties(valid PROPERTIES LINKER_LANGUAGE CXX)


set(WORKLOAD_RUN main.cc micro_bench.cc)

add_executable(validations ${WORKLOAD_RUN})

target_link_libraries(validations valid stat ${WORKLOAD_LIB})
#! /bin/bash

# This uses the following directories:
# Workspace/qa-fuzz: Fuzz build of latest master configured without sanitizers
# Workspace/qa-merge: Fuzz build of latest master configured with all sanitizers
# Workspace/qa-assets-active-fuzzing/fuzz_corpora: Directory for collecting new fuzz inputs from nightly fuzzing

notify-send -u critical 'Starting fuzz job' && \
# Suppress false positives in sanitizers
export UBSAN_OPTIONS=suppressions=test/sanitizer_suppressions/ubsan:print_stacktrace=1:halt_on_error=1:report_error_type=1
# Update and compile fuzz binary with sanitizers disabled
cd $HOME/Workspace/qa-fuzz && \
git reset --hard upstream/master && \
cmake --build build_fuzz -j "$(($(nproc)+1))" && \
# Update and compile fuzz binary with all sanitizers enabled
cd $HOME/Workspace/qa-merge && \
git reset --hard upstream/master && \
cmake --build build_fuzz -j "$(($(nproc)+1))" && \
for i in $(find ../qa-assets-active-fuzzing/fuzz_corpora/ -mindepth 1 -maxdepth 1 -type d | shuf | head -n10);
    do notify-send -u critical 'Fuzzing '+$i && \
    cd $HOME/Workspace/qa-fuzz && \
    # Run a few threads without sanitizers to run at limited length to foster reduced length seeds
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=32 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=96 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -reload=1 -max_total_time=3600 -max_len=96 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=288 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -reload=1 -max_total_time=3600 -max_len=288 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=864 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -reload=1 -max_total_time=3600 -max_len=864 $i & \
    # Run most threads without sanitizers
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=18 -reload=1 -max_total_time=3600 $i & \
    # Run a thread each with and without use_value_profile and all sanitizers enabled
    cd $HOME/Workspace/qa-merge && \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -reload=1 -max_total_time=3600 $i & \
    wait; done; notify-send -u critical 'FINISHED FUZZING 10 QA-ASSETS for 28×1h each'
#! /bin/bash
notify-send -u critical 'Starting fuzz job' && \
cd $HOME/Workspace/qa-fuzz && \
git reset --hard upstream/master && \
cmake --build build_fuzz -j "$(($(nproc)+1))" && \
for i in $(find ../qa-assets-active-fuzzing/fuzz_corpora/ -mindepth 1 -maxdepth 1 -type d | grep $1);
    do notify-send -u critical 'Fuzzing '+$i && \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=32 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=128 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -reload=1 -max_total_time=3600 -max_len=128 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=512 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -reload=1 -max_total_time=3600 -max_len=512 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 -max_len=2048 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -reload=1 -max_total_time=3600 -max_len=2048 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=1 -use_value_profile=1 -reload=1 -max_total_time=3600 $i & \
    FUZZ=$(basename $i) build_fuzz/src/test/fuzz/fuzz -fork=8 -reload=1 -max_total_time=3600 $i & \
    wait; done; notify-send -u critical 'FINISHED FUZZING ' +$i + ' for 16×1h'

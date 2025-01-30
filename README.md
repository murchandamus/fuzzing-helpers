# Automatic nightly fuzzing

## Setup

My setup uses four branches of repositories for the process:

- ~/Workspace/qa-assets  
    A branch of the https://github.com/bitcoin-core/qa-assets repository on GitHub. It is used to hold the latest state of the upstream repository and to create submission to the upstream repository. There is a fuzz corpus for each fuzz target in the `fuzz_corpora` directory.
- ~/Workspace/qa-assets-active-fuzzing  
    A second branch of the https://github.com/bitcoin-core/qa-assets repository on GitHub. The inputs generated from nightly fuzzing are stored in this directory. There is a fuzz corpus for each fuzz target in the `fuzz_corpora` directory.
- ~/Workspace/qa-fuzz  
    A fuzz build of Bitcoin Core configured to __not__ use any sanitizers. Updated automatically every night to the latest konwn commit of the bitcoin/bitcoin master branch.
- ~/Workspace/qa-merge  
    A fuzz build of Bitcoin Core configured to use __all__ any sanitizers. Used to create submissions to the upstream qa-assets repository.

    ```
    cmake -B build_fuzz \
       -DCMAKE_C_COMPILER="clang" \
       -DCMAKE_CXX_COMPILER="clang++" \
       -DBUILD_FOR_FUZZING=ON \
       -DSANITIZERS=undefined,address,fuzzer,float-divide-by-zero,integer
    ```

## Nightly fuzzing

The `fuzz_nightly.sh` script randomly picks ten fuzz targets and fuzzes each with 28 threads for an hour. The script mixes in a few threads that turn on `use_value_profile`, use sanitizers, and restrict the length of inputs, but most threads are unrestricted in all of these regards.

I run a cronjob at 9 PM every night that starts an instance of the `fuzz_nightly.sh` script, and a cronjob that starts an instance of the `fuzz_nightly.sh` script at 9 AM on Saturday and Sunday:

```
0 21 * * * export DISPLAY=:0.0 && /bin/zsh /home/murch/.local/bin/fuzz_nightly.sh > ~/.cron.log 2>&1
0 9 * * 6,7 export DISPLAY=:0.0 && /bin/zsh /home/murch/.local/bin/fuzz_nightly.sh > ~/.cron.log 2>&1
```

The "DISPLAY" part was necessary for making the notifications in the script show up on the screen.

## Fuzzing a specific target

To generate fuzzing inputs for a specific target, I use the `fuzz_given.sh` script. It takes a single string argument that it uses to grep among the directories in `qa-assets-active-fuzzing/fuzz_corpora`. It will fuzz each hit for one hour with 16 threads.

Calling

```
~/.local/bin/fuzz_given.sh fees
```

would for example fuzz the two targets `fees` and `wallet_fees`. You can fuzz exactly one target by passing the `-w` parameter along the search term, i.e., calling

```
~/.local/bin/fuzz_given.sh "-w fees"
```

will only match on the `fees` target.

## Upstreaming the results (about every two months)

1. Pull the latest Bitcoin Core
```
cd ~/Workspace/qa-merge
git pull upstream master
git reset --hard upstream/master
```

2. Build the merge setup
```
cd ~/Workspace/qa-merge
cmake --build build_fuzz -j 20
```

3. Enable suppressions
```
cd ~/Workspace/qa-merge
export UBSAN_OPTIONS=suppressions=test/sanitizer_suppressions/ubsan:print_stacktrace=1:halt_on_error=1:report_error_type=1
```

4. Check out a branch for the upstream submission
```
cd ~/Workspace/qa-assets
git pull upstream main
git reset --hard upstream/main
git checkout -b "202y-mm-murch-inputs"
```

5. Move aside the upstream fuzz inputs to make room for a new corpora
```
cd ~/Workspace/qa-assets
mv fuzz_corpora upstream_corpora
```

6. Declutter the active fuzzing directory by moving current input collection aside and deleting the one from two months prior
```
cd ~/Workspace/qa-assets-active-fuzzing
rm -r old_corpora
mv fuzz_corpora old_corpora
git reset --hard upstream/main
```

7. Create fresh corpora for all fuzz targets by merging the upstream corpora, active fuzzing corpora, and old corpora into new corpora
```
cd ~/Workspace/qa-merge
build_fuzz/test/fuzz/test_runner.py -l DEBUG --par 3 --m_dir ../qa-assets-active-fuzzing/fuzz_corpora/ --m_dir ../qa-assets-active-fuzzing/old_corpora --m_dir ../qa-assets/upstream_corpora/ ../qa-assets/fuzz_corpora/
```

Note: Depending on what state `../qa-assets-active-fuzzing/fuzz_corpora` and `../qa-assets/upstream_corpora` have at the time of the merge, the two might be an exact duplicate or one may be a subset of the other.

8. After the merge is finished, restore the upstream inputs
```
cd ~/Workspace/qa-assets
git restore -- ./fuzz_corpora
```

9. Commit and push
```
cd ~/Workspace/qa-assets
git add fuzz_corpora
git commit -m "Add Murch’s inputs MONTH YYYY"
```


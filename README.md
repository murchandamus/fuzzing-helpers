# Automatic nightly fuzzing

## Setup

My setup uses four branches of repositories for the process:

- ~/Workspace/qa-assets  
    A branch of the https://github.com/bitcoin-core/qa-assets repository on GitHub. It is used to hold the latest state of the upstream repository and to create submissions to the upstream repository. There is a fuzz corpus for each fuzz target in the `fuzz_corpora` directory.
- ~/Workspace/qa-assets-active-fuzzing  
    A second branch of the https://github.com/bitcoin-core/qa-assets repository on GitHub. The inputs generated from nightly fuzzing are stored in this directory. There is a fuzz corpus for each fuzz target in the `fuzz_corpora` directory.
- ~/Workspace/qa-fuzz  
    A fuzz build of Bitcoin Core configured to __not__ use any sanitizers. Updated automatically every night to the latest known commit of the bitcoin/bitcoin master branch.
- ~/Workspace/qa-fuzz-sanitized  
    A fuzz build of Bitcoin Core configured to use __all__ any sanitizers. Updated automatically every night to the latest known commit of the bitcoin/bitcoin master branch. Used to ensure that all new input additions found by other threads are also tested against sanitizers.

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
cd ~/Workspace/qa-fuzz
git pull upstream master
git reset --hard upstream/master
```

2. Build the merge setup with the latest version
```
cd ~/Workspace/qa-fuzz
cmake --build build_fuzz -j 20
```

3. Enable suppressions
```
cd ~/Workspace/qa-fuzz
export UBSAN_OPTIONS=suppressions=test/sanitizer_suppressions/ubsan:print_stacktrace=1:halt_on_error=1:report_error_type=1
```

4. Check out a branch for the upstream submission
```
cd ~/Workspace/qa-assets
git pull upstream main
git reset --hard upstream/main
git checkout -b "202y-mm-murch-inputs"
```

5. Move aside the upstream fuzz inputs to make room for new corpora
```
cd ~/Workspace/qa-assets
mv fuzz_corpora upstream_corpora
mkdir fuzz_corpora
```

6. Declutter the active fuzzing directory by moving the candidates for the submission aside and deleting the candidates from two months prior
```
cd ~/Workspace/qa-assets-active-fuzzing
rm -r candidate_corpora
mv fuzz_corpora candidate_corpora
git reset --hard upstream/main
```

Retaining the state of the candidate fuzz corpora at the merge time allows us to rebuild another submission from the same data in case we aim for comparability.

7. Create fresh corpora for all fuzz targets by merging the upstream corpora, active fuzzing corpora, and old corpora into new corpora
```
cd ~/Workspace/qa-fuzz
build_fuzz/test/fuzz/test_runner.py -l DEBUG --par 3 --m_dir ../qa-assets-active-fuzzing/candidate_corpora --m_dir ../qa-assets/upstream_corpora/ ../qa-assets/fuzz_corpora/
```

Note: For repeatability, `../qa-assets-active-fuzzing/fuzz_corpora` is not included, as it will start being populated per the subsequent nightly fuzzing. This also makes it clear which inputs were already considered for submission. Either way, right after setting aside `../qa-assets-active-fuzzing/candidate_corpora` and resetting `../qa-assets-active-fuzzing/fuzz_corpora`, the latter should be an exact duplicate of `../qa-assets/upstream_corpora`. After nightly fuzzing has occurred, `../qa-assets/upstream_corpora` will be a subset of `../qa-assets-active-fuzzing/fuzz_corpora`. If repeatability is not necessary or we don’t care that inputs may be considered for submission twice, the submission can instead be crafted by adding the latest inputs:

```
cd ~/Workspace/qa-fuzz
build_fuzz/test/fuzz/test_runner.py -l DEBUG --par 3 --m_dir ../qa-assets-active-fuzzing/candidate_corpora --m_dir ../qa-assets-active-fuzzing/fuzz_corpora/ ../qa-assets/fuzz_corpora/
```

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


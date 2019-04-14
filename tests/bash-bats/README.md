# BATS Bash Testing

For each bash script we have, there should be a separate .sh file within ROOT/tests/bash-bats/.

**You must have bats installed: ([Source Install Instructions](https://github.com/bats-core/bats-core#installing-bats-from-source))** || `brew install bats-core`

 - Running all tests: 
    ```
    $ bats tests/bash-bats/*.bash
      ✓ [eosio_build_darwin] > Testing -y/NONINTERACTIVE/PROCEED
      ✓ [eosio_build_darwin] > Testing prompts
      ✓ [eosio_build_darwin] > Testing executions
      ✓ [helpers] > execute > dryrun
      ✓ [helpers] > execute > verbose
      ✓ [uninstall] > Usage is visible with right interaction
      ✓ [uninstall] > Testing user prompts
      ✓ [uninstall] > Testing executions
      ✓ [uninstall] > --force
      ✓ [uninstall] > --force + --full

      10 tests, 0 failures
    ```
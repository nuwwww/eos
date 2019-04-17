# BATS Bash Testing

For each bash script we have, there should be a separate .bash file within ROOT/tests/bash-bats/.

- DRYRUN=true is required for all tests. This can be used to ensure the right commands are being run without executing them.
- **MacOSX: You must have bats installed: ([Source Install Instructions](https://github.com/bats-core/bats-core#installing-bats-from-source))** || `brew install bats-core`

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

---

### Running Docker Environments for Testing
  1. `docker run -v $HOME/eos:/eos -ti amazonlinux:1 /bin/bash`
      - You'll need to modify the volume path ($HOME/eos) to indicate where you've got eos cloned locally.
  2. `tests/bash-bats/bats-core/bin/bats tests/bash-bats/*.bash`
      ``` 
      bash-4.2# tests/bash-bats/bats-core/bin/bats tests/bash-bats/*.bash
      ✓ [eosio_build_amazonlinux] > Testing -y/NONINTERACTIVE/PROCEED
      ✓ [eosio_build_amazonlinux] > Testing prompts
      ✓ [eosio_build_amazonlinux] > Testing CMAKE Install
      ✓ [eosio_build_amazonlinux] > Testing executions
      ✓ begin 16 [eosio_uninstall] > Usage is visible with right interaction
      ✓ begin 17 [eosio_uninstall] > Testing user prompts
      ✓ begin 18 [eosio_uninstall] > Testing executions
      ✓ begin 19 [eosio_uninstall] > --force
      ✓ begin 20 [eosio_uninstall] > --force + --full
      ✓ begin 21 [helpers] > execute > dryrun
      ✓ begin 22 [helpers] > execute > verbose

      22 tests, 0 failures
      ```

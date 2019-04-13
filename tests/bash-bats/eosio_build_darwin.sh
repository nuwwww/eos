#!/usr/bin/env bats
load test_helper

SCRIPT_LOCATION="scripts/eosio_build.bash"
TEST_LABEL="[eosio_build_darwin]"

# A helper function is available to show output and status: `debug`

@test "${TEST_LABEL} > Testing user prompts" {
  ## No y or no warning and re-prompt
  run bash -c "echo -e \"\nx\nx\nx\" | ./$SCRIPT_LOCATION"
  debug
  ( [[ "${lines[3]}" == "Please type 'y' for yes or 'n' for no." ]] && [[ "${lines[2]}" == "Please type 'y' for yes or 'n' for no." ]] ) || exit
  ## All yes pass
  run bash -c "printf \"y\n%.0s\" {1..100} | ./$SCRIPT_LOCATION"
  [[ "${output##*$'\n'}" == "[EOSIO Removal Complete]" ]] || exit
  ## First no shows "Cancelled..."
  run bash -c "echo \"n\" | ./$SCRIPT_LOCATION"
  [[ "${lines[0]}" =~ "Cancelled EOSIO Removal!" ]] || exit
  ## What would you like to do?"
  run bash -c "echo \"\" | ./$SCRIPT_LOCATION"
  [[ "${lines[0]}" =~ "What would you like to do?" ]] || exit
}
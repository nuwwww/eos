#!/usr/bin/env bats
load test_helper

SCRIPT_LOCATION="scripts/eosio_build.bash"
TEST_LABEL="[eosio_build_darwin]"

[[ $ARCH == "Darwin" ]] || exit 0 # Exit 0 is required for pipeline
[[ $NAME == "Mac OS X" ]] || exit 0 # Exit 0 is required for pipeline

# A helper function is available to show output and status: `debug`

@test "${TEST_LABEL} > Testing -y/NONINTERACTIVE/PROCEED" {
    # FOR LOOP EACH PROMPT AND TEST THE SAME SET OF TESTS
    run bash -c "./$SCRIPT_LOCATION -y"
    [[ ! -z $(echo "${output}" | grep "EOSIO has been successfully built") ]] || exit
}

@test "${TEST_LABEL} > Testing prompts" {
#   ## All yes pass
  run bash -c "printf \"y\n%.0s\" {1..100} | ./$SCRIPT_LOCATION"
  [[ ! -z $(echo "${output}" | grep "EOSIO has been successfully built") ]] || exit
  ## First no shows "aborting"  
  run bash -c "printf \"n\n%.0s\" {1..2} | ./$SCRIPT_LOCATION"
  [[ "${output##*$'\n'}" =~ "- User aborted installation of required dependencies." ]] || exit
}

@test "${TEST_LABEL} > Testing executions" {
  export CMAKE=/usr/local/bin/cmake # Necessary just in case it's not brew installed
  run bash -c "printf \"y\n%.0s\" {1..100} | ./$SCRIPT_LOCATION"
  ### Make sure deps are loaded properly
  [[ ! -z $(echo "${output}" | grep "Starting EOSIO Dependency Install") ]] || exit
  [[ ! -z $(echo "${output}" | grep "Executing: /usr/bin/xcode-select --install") ]] || exit
  [[ ! -z $(echo "${output}" | grep "Executing: stat /usr/local/bin/automake") ]] || exit
  [[ ! -z $(echo "${output}" | grep automake.*found) ]] || exit
  [[ ! -z $(echo "${output}" | grep "[Updating HomeBrew]") ]] || exit
  [[ ! -z $(echo "${output}" | grep "brew tap eosio/eosio") ]] || exit
  [[ ! -z $(echo "${output}" | grep "brew install cmake") ]] || exit
  [[ ! -z $(echo "${output}" | grep ${HOME}.*/src/boost) ]] || exit
  [[ ! -z $(echo "${output}" | grep "Starting EOSIO Build") ]] || exit
  [[ ! -z $(echo "${output}" | grep "Executing: /usr/local/bin/cmake") ]] || exit
}
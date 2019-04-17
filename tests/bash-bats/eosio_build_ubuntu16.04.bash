#!/usr/bin/env bats
load test_helper

SCRIPT_LOCATION="scripts/eosio_build.bash"
TEST_LABEL="[eosio_build_ubuntu16.04]"

[[ $ARCH == "Linux" ]] || exit 1 # Skip if we're not on linux
[[ $NAME == "Ubuntu" ]] || exit 1
[[ $VERSION_ID == "16.04" ]] || exit 1

# A helper function is available to show output and status: `debug`

@test "${TEST_LABEL} > Testing -y/NONINTERACTIVE/PROCEED" {
    # FOR LOOP EACH PROMPT AND TEST THE SAME SET OF TESTS
    run bash -c "./$SCRIPT_LOCATION -y"
    [[ ! -z $(echo "${output}" | grep "EOSIO has been successfully built") ]] || exit
}

@test "${TEST_LABEL} > Testing prompts" {
    ## All yes pass
    run bash -c "printf \"y\n%.0s\" {1..100} | ./$SCRIPT_LOCATION"
    [[ ! -z $(echo "${output}" | grep "EOSIO has been successfully built") ]] || exit
    ## First no shows "aborting"  
    run bash -c "printf \"n\n%.0s\" {1..2} | ./$SCRIPT_LOCATION"
    [[ "${output##*$'\n'}" =~ "- User aborted installation of required dependencies." ]] || exit
}

@test "${TEST_LABEL} > Testing executions" {
    run bash -c "printf \"y\n%.0s\" {1..100} | ./$SCRIPT_LOCATION"
    ### Make sure deps are loaded properly
    [[ ! -z $(echo "${output}" | grep "Starting EOSIO Dependency Install") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Executing: sudo /usr/bin/apt-get update") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Executing: dpkg-query -l make") ]] || exit
    [[ ! -z $(echo "${output}" | grep "Installing CMAKE") ]] || exit
    [[ ! -z $(echo "${output}" | grep ${HOME}.*/src/boost) ]] || exit
    [[ ! -z $(echo "${output}" | grep "Starting EOSIO Build") ]] || exit
    [[ ! -z $(echo "${output}" | grep "make -j${CPU_CORES}") ]] || exit
}
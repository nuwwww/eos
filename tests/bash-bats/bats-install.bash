#!/usr/bin/env bash
pwd
if [[ -z "$(command -v bats 2>/dev/null)" ]]; then
    pushd tests/bash-bats/bats-core
    ./install.sh /usr/local
    popd
fi
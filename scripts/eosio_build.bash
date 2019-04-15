#!/usr/bin/env bash
set -eo pipefail
VERSION=3.0 # Build script version (change this to re-build the CICD image)
##########################################################################
# This is the EOSIO automated install script for Linux and Mac OS.
# This file was downloaded from https://github.com/EOSIO/eos
#
# Copyright (c) 2017, Respective Authors all rights reserved.
#
# After June 1, 2018 this software is available under the following terms:
#
# The MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# https://github.com/EOSIO/eos/blob/master/LICENSE
##########################################################################

TIME_BEGIN=$( date -u +%s )

# Obtain dependency versions; Must come first in the script
. ./scripts/.environment

# Load bash script helper functions
. ./scripts/lib/helpers.bash

# Load eosio specific helper functions
. ./scripts/lib/eosio.bash
# Setup directories and envs we need
setup
# Setup tmp directory; handle if noexec exists
setup-tmp

if [ $# -ne 0 ]; then
   while getopts ":cdo:s:hy" opt; do
      case "${opt}" in
         o )
            options=( "Debug" "Release" "RelWithDebInfo" "MinSizeRel" )
            if [[ "${options[*]}" =~ "${OPTARG}" ]]; then
               CMAKE_BUILD_TYPE="${OPTARG}"
            else
               printf "\\nInvalid argument: %s\\n" "${OPTARG}" 1>&2
               usage
               exit 1
            fi
         ;;
         c )
            ENABLE_COVERAGE_TESTING=true
         ;;
         d )
            DOXYGEN=true
         ;;
         s)
            if [ "${#OPTARG}" -gt 7 ] || [ -z "${#OPTARG}" ]; then
               printf "\\nInvalid argument: %s\\n" "${OPTARG}" 1>&2
               usage
               exit 1
            else
               CORE_SYMBOL_NAME="${OPTARG}"
            fi
         ;;
         h)
            usage
            exit 1
         ;;
         y)
            NONINTERACTIVE=true
            PROCEED=true
         ;;
         \? )
            printf "\\nInvalid Option: %s\\n" "-${OPTARG}" 1>&2
            usage
            exit 1
         ;;
         : )
            printf "\\nInvalid Option: %s requires an argument.\\n" "-${OPTARG}" 1>&2
            usage
            exit 1
         ;;
         * )
            usage
            exit 1
         ;;
      esac
   done
fi

# Prevent a non-git clone from running
ensure-git-clone

execute cd $REPO_ROOT

# Submodules need to be up to date
ensure-submodules-up-to-date

printf "\\nBeginning build version: %s\\n" "${VERSION}"
printf "%s\\n" "$( date -u )"
printf "User: %s\\n" "$( whoami )"
# printf "git head id: %s\\n" "$( cat .git/refs/heads/master )"
printf "Current branch: %s\\n" "$( git rev-parse --abbrev-ref HEAD )"

# Setup based on architecture
export CMAKE=$(command -v cmake 2>/dev/null)
printf "\\nARCHITECTURE: %s\\n" "${ARCH}"
if [ "$ARCH" == "Linux" ]; then
   # Check if cmake is already installed or not and use source install location
   if [ -z $CMAKE ]; then export CMAKE=$HOME/bin/cmake; fi
   export OS_NAME=$( cat /etc/os-release | grep ^NAME | cut -d'=' -f2 | sed 's/\"//gI' )
   OPENSSL_ROOT_DIR=/usr/include/openssl
   if [ ! -e /etc/os-release ]; then
      printf "\\nEOSIO currently supports Amazon, Centos, Fedora, Mint & Ubuntu Linux only.\\n"
      printf "Please install on the latest version of one of these Linux distributions.\\n"
      printf "https://aws.amazon.com/amazon-linux-ami/\\n"
      printf "https://www.centos.org/\\n"
      printf "https://start.fedoraproject.org/\\n"
      printf "https://linuxmint.com/\\n"
      printf "https://www.ubuntu.com/\\n"
      printf "Exiting now.\\n"
      exit 1
   fi
   case "$OS_NAME" in
      "Amazon Linux AMI"|"Amazon Linux")
         FILE="${REPO_ROOT}/scripts/eosio_build_amazon.bash"
         CXX_COMPILER=g++
         C_COMPILER=gcc
      ;;
      "CentOS Linux")
         FILE="${REPO_ROOT}/scripts/eosio_build_centos.bash"
         CXX_COMPILER=g++
         C_COMPILER=gcc
      ;;
      "elementary OS")
         FILE="${REPO_ROOT}/scripts/eosio_build_ubuntu.bash"
         CXX_COMPILER=clang++-4.0
         C_COMPILER=clang-4.0
      ;;
      "Fedora")
         export CPATH=/usr/include/llvm4.0:$CPATH # llvm4.0 for fedora package path inclusion
         FILE="${REPO_ROOT}/scripts/eosio_build_fedora.bash"
         CXX_COMPILER=g++
         C_COMPILER=gcc
      ;;
      "Linux Mint")
         FILE="${REPO_ROOT}/scripts/eosio_build_ubuntu.bash"
         CXX_COMPILER=clang++-4.0
         C_COMPILER=clang-4.0
      ;;
      "Ubuntu")
         FILE="${REPO_ROOT}/scripts/eosio_build_ubuntu.bash"
         CXX_COMPILER=clang++-4.0
         C_COMPILER=clang-4.0
      ;;
      "Debian GNU/Linux")
         FILE="${REPO_ROOT}/scripts/eosio_build_ubuntu.bash"
         CXX_COMPILER=clang++-4.0
         C_COMPILER=clang-4.0
      ;;
      *)
         printf "\\nUnsupported Linux Distribution. Exiting now.\\n\\n"
         exit 1
   esac
fi

if [ "$ARCH" == "Darwin" ]; then
   [[ -z "${CMAKE}" ]] && export CMAKE=/usr/local/bin/cmake # Check if cmake is already installed or not and use source install location
   export OS_NAME=MacOSX
   # opt/gettext: cleos requires Intl, which requires gettext; it's keg only though and we don't want to force linking: https://github.com/EOSIO/eos/issues/2240#issuecomment-396309884
   # HOME/lib/cmake: mongo_db_plugin.cpp:25:10: fatal error: 'bsoncxx/builder/basic/kvp.hpp' file not found
   LOCAL_CMAKE_FLAGS="-DCMAKE_PREFIX_PATH=/usr/local/opt/gettext;$HOME/lib/cmake ${LOCAL_CMAKE_FLAGS}" 
   FILE="${SCRIPT_DIR}/eosio_build_darwin.bash"
   CXX_COMPILER=clang++
   C_COMPILER=clang
   OPENSSL_ROOT_DIR=/usr/local/opt/openssl
fi

printf "\\n${COLOR_CYAN}====================================================================================="
printf "\\n======================= ${COLOR_WHITE}Starting EOSIO Dependency Install${COLOR_CYAN} ===========================${COLOR_NC}\\n"
execute pushd $SRC_LOCATION 1>/dev/null
. $FILE # Execute OS specific build file
execute popd 1>/dev/null

printf "\\n${COLOR_CYAN}========================================================================"
printf "\\n======================= ${COLOR_WHITE}Starting EOSIO Build${COLOR_CYAN} ===========================\\n"
printf "[${COLOR_NC}CMAKE_BUILD_TYPE=%s${COLOR_CYAN}] " "${CMAKE_BUILD_TYPE}"
printf "              [${COLOR_NC}ENABLE_COVERAGE_TESTING=%s${COLOR_CYAN}]${COLOR_NC}\\n\\n" "${ENABLE_COVERAGE_TESTING}"

execute mkdir -p $BUILD_DIR
execute pushd $BUILD_DIR 1>/dev/null
execute $CMAKE -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" -DCMAKE_CXX_COMPILER="${CXX_COMPILER}" -DCMAKE_C_COMPILER="${C_COMPILER}" -DCORE_SYMBOL_NAME="${CORE_SYMBOL_NAME}" -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR}" -DBUILD_MONGO_DB_PLUGIN=true -DENABLE_COVERAGE_TESTING="${ENABLE_COVERAGE_TESTING}" -DBUILD_DOXYGEN="${DOXYGEN}" -DCMAKE_INSTALL_PREFIX="${OPT_LOCATION}/eosio" ${LOCAL_CMAKE_FLAGS} "${REPO_ROOT}"
execute make -j"${JOBS}"
execute popd $REPO_ROOT 1>/dev/null

TIME_END=$(( $(date -u +%s) - $TIME_BEGIN ))

printf "${COLOR_RED}\n_______  _______  _______ _________ _______\n"
printf '(  ____ \(  ___  )(  ____ \\\\__   __/(  ___  )\n'
printf "| (    \/| (   ) || (    \/   ) (   | (   ) |\n"
printf "| (__    | |   | || (_____    | |   | |   | |\n"
printf "|  __)   | |   | |(_____  )   | |   | |   | |\n"
printf "| (      | |   | |      ) |   | |   | |   | |\n"
printf "| (____/\| (___) |/\____) |___) (___| (___) |\n"
printf "(_______/(_______)\_______)\_______/(_______)\n=============================================\n${COLOR_NC}"

printf "${COLOR_GREEN}EOSIO has been successfully built. %02d:%02d:%02d" $(($TIME_END/3600)) $(($TIME_END%3600/60)) $(($TIME_END%60))
printf "\\n${COLOR_GREEN}You can now install using: ./scripts/eosio_install.bash${COLOR_NC}"
printf "\\n${COLOR_YELLOW}Uninstall with: ./scripts/eosio_uninstall.bash${COLOR_NC}\\n"

printf "\n"
printf "${COLOR_CYAN}If you wish to perform tests to ensure functional code:${COLOR_NC}\\n"
print_instructions
printf "1. Start Mongo: ${BIN_LOCATION}/mongod --dbpath ${MONGODB_DATA_LOCATION} -f ${MONGODB_CONF} --logpath ${MONGODB_LOG_LOCATION}/mongod.log &\\n"
printf "2. Run Tests: cd ./build && PATH=\$PATH:$HOME/opt/mongodb/bin make test\\n" # PATH is set as currently 'mongo' binary is required for the mongodb test
printf "\n"
resources

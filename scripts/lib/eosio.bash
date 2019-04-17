# Obtain dependency versions; Must come first in the script
. ./scripts/.environment
# Load general helpers
. ./scripts/lib/helpers.bash

# Checks for Arch and OS + Support for tests setting them manually
## Necessary for linux exclusion while running bats tests/bash-bats/*.bash
[[ -z "${ARCH}" ]] && export ARCH=$( uname )
if [[ -z "${NAME}" ]]; then
    if [[ $ARCH == "Linux" ]]; then 
        [[ ! -e /etc/os-release ]] && echo "${COLOR_RED} - /etc/os-release not found! It seems you're attempting to use an unsupported Linux distribution.${COLOR_NC}" && exit 1
        # Obtain OS NAME, and VERSION
        . /etc/os-release
    elif [[ $ARCH == "Darwin" ]]; then export NAME=$(sw_vers -productName)
    else echo " ${COLOR_RED}- EOSIO is not supported for your Architecture!${COLOR_NC}" && exit 1
    fi
fi

function usage() {
   printf "Usage: %s \\n
   [Build Option -o <Debug|Release|RelWithDebInfo|MinSizeRel>]
   \\n[CodeCoverage -c] 
   \\n[Doxygen -d]
   \\n[CoreSymbolName -s <1-7 characters>]
   \\n[Avoid Compiling -a]
   \\n[Noninteractive -y]
   \\n\\n" "$0" 1>&2
   exit 1
}

function setup() {
    execute mkdir -p $SRC_LOCATION
    execute mkdir -p $OPT_LOCATION
    execute mkdir -p $VAR_LOCATION
    execute mkdir -p $BIN_LOCATION
    execute mkdir -p $VAR_LOCATION/log
    execute mkdir -p $ETC_LOCATION
    execute mkdir -p $LIB_LOCATION
    execute mkdir -p $MONGODB_LOG_LOCATION
    execute mkdir -p $MONGODB_DATA_LOCATION
}

function resources() {
    printf "${COLOR_CYAN}EOSIO website:${COLOR_NC} https://eos.io\\n"
    printf "${COLOR_CYAN}EOSIO Telegram channel:${COLOR_NC} https://t.me/EOSProject\\n"
    printf "${COLOR_CYAN}EOSIO resources:${COLOR_NC} https://eos.io/resources/\\n"
    printf "${COLOR_CYAN}EOSIO Stack Exchange:${COLOR_NC} https://eosio.stackexchange.com\\n"
}
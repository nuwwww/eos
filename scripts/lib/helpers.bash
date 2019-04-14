export COLOR_NC=$(tput sgr0) # No Color
export COLOR_RED=$(tput setaf 1)
export COLOR_GREEN=$(tput setaf 2)
export COLOR_YELLOW=$(tput setaf 3)
export COLOR_BLUE=$(tput setaf 4)
export COLOR_MAGENTA=$(tput setaf 5)
export COLOR_CYAN=$(tput setaf 6)
export COLOR_WHITE=$(tput setaf 7)

function execute() {
  ( [[ ! -z "${VERBOSE}" ]] && $VERBOSE ) && echo " - Executing: $@"
  ( [[ ! -z "${DRYRUN}" ]] && $DRYRUN ) || "$@"
}

function setup-tmp() {
  # Use current directory's tmp directory if noexec is enabled for /tmp
  if (mount | grep "/tmp " | grep --quiet noexec); then
    [[ -z "${REPO_ROOT}" ]] && echo "\$REPO_ROOT not set" && exit 1
    mkdir -p $REPO_ROOT/tmp
    TEMP_DIR="${REPO_ROOT}/tmp"
    rm -rf $REPO_ROOT/tmp/*
  else # noexec wasn't found
    TEMP_DIR="/tmp"
  fi
}

function ensure-git-clone() {
  if [ ! -d "${REPO_ROOT}/.git" ]; then
    printf "\\nThis build script only works with sources cloned from git\\n"
    printf "For example, you can clone a new eos directory with: git clone https://github.com/EOSIO/eos\\n"
    exit 1
  fi
}

function ensure-submodules-up-to-date() {
  if [[ $(git submodule status --recursive | grep -c "^[+\-]") -gt 0 ]]; then
    printf "git submodules are not up to date.\\n"
    printf "Please run the command 'git submodule update --init --recursive'.\\n"
    exit 1
  fi
}
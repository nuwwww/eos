# You can add `load test_helper` to the .bats files you create to include anything in this file.

# DO NOT REMOVE
export DRYRUN=true
export VERBOSE=true

# Arrays should return with newlines so we can do something like "${output##*$'\n'}" to get the last line
IFS=$'\n'

function execute() {
  echo "[Executing: $@]" >&3
  "$@"
}

# Ensure we're in the root directory to execute
if [[ ! -d "tests" ]] && [[ ! -f "README.md" ]]; then
  echo "You must navigate into the root directory to execute tests..." >&3
  exit 1
fi

create_home_dir() {
  echo "[Create User Home Directory]" >&3
  export HOME="$BATS_TMPDIR/bats-eosio-user-home" # Ensure $HOME is available for all scripts
  execute mkdir -p $HOME
}

create_home_dirs() {
  echo "[Create User Home Directories (~/src, opt, etc)]" >&3
  # Obtain dependency versions
  . ./scripts/.environment
  execute mkdir -p $SRC_LOCATION
  execute mkdir -p $OPT_LOCATION
  execute mkdir -p $VAR_LOCATION
  execute mkdir -p $BIN_LOCATION
  execute mkdir -p $VAR_LOCATION/log
  execute mkdir -p $ETC_LOCATION
  execute mkdir -p $MONGODB_LOG_LOCATION
  execute mkdir -p $MONGODB_DATA_LOCATION
}

debug() {
  printf " ---------\\n STATUS: ${status}\\n${output}\\n ---------\\n\\n" >&3
}

setup() { # setup is run once before each test
  echo -e "\n-- SETUP --" >&3
  create_home_dir
  create_home_dirs
  create_eosio_dir
  create_eosio_data_dir
  echo -e "-- END SETUP --\n" >&3
}

teardown() { # teardown is run once after each test, even if it fails
  echo -e "\n-- CLEANUP --" >&3
  [[ -n "$HOME" ]] && execute rm -rf "$HOME"
  echo -e "-- END CLEANUP --\n" >&3
}

create_eosio_dir () {
  echo "[Create eosio directory]"
  execute mkdir -p $HOME/opt/eosio
}
create_eosio_data_dir () {
  echo "[Create eosio data directory]"
  execute mkdir -p $HOME/Library/Application\ Support/eosio
}
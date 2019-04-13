[[ -z $VERBOSE ]] && export VERBOSE=false || echo "[VERBOSE OUTPUT ENABLED]" # Support tests + Disable execution messages in STDOUT
[[ -z $DRYRUN ]] && export DRYRUN=false || echo "[DRYRUN ENABLED]" # Support tests + Disable execution, just STDOUT

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
    execute mkdir -p $MONGODB_LOG_LOCATION
    execute mkdir -p $MONGODB_DATA_LOCATION
}
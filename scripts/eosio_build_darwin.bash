OS_VER=$(sw_vers -productVersion)
OS_MAJ=$(echo "${OS_VER}" | cut -d'.' -f1)
OS_MIN=$(echo "${OS_VER}" | cut -d'.' -f2)
OS_PATCH=$(echo "${OS_VER}" | cut -d'.' -f3)
MEM_GIG=$(bc <<< "($(sysctl -in hw.memsize) / 1024000000)")
CPU_SPEED=$(bc <<< "scale=2; ($(sysctl -in hw.cpufrequency) / 10^8) / 10")
CPU_CORE=$( sysctl -in machdep.cpu.core_count )
export JOBS=$(( MEM_GIG > CPU_CORE ? CPU_CORE : MEM_GIG ))

DISK_INSTALL=$(df -h . | tail -1 | tr -s ' ' | cut -d\  -f1 || cut -d' ' -f1)
blksize=$(df . | head -1 | awk '{print $2}' | cut -d- -f1)
gbfactor=$(( 1073741824 / blksize ))
total_blks=$(df . | tail -1 | awk '{print $2}')
avail_blks=$(df . | tail -1 | awk '{print $4}')
DISK_TOTAL=$((total_blks / gbfactor ))
DISK_AVAIL=$((avail_blks / gbfactor ))

export HOMEBREW_NO_AUTO_UPDATE=1

COUNT=1
DISPLAY=""
DEPS=""

printf "\\nOS name: ${OS_NAME}\\n"
printf "OS Version: ${OS_VER}\\n"
printf "CPU speed: ${CPU_SPEED}Mhz\\n"
printf "CPU cores: %s\\n" "${CPU_CORE}"
printf "Physical Memory: ${MEM_GIG} Gbytes\\n"
printf "Disk install: ${DISK_INSTALL}\\n"
printf "Disk space total: ${DISK_TOTAL}G\\n"
printf "Disk space available: ${DISK_AVAIL}G\\n"

if [ "${MEM_GIG}" -lt 7 ]; then
	echo "Your system must have 7 or more Gigabytes of physical memory installed."
	echo "Exiting now."
	exit 1
fi

if [ "${OS_MIN}" -lt 12 ]; then
	echo "You must be running Mac OS 10.12.x or higher to install EOSIO."
	echo "Exiting now."
	exit 1
fi

if [ "${DISK_AVAIL}" -lt "$DISK_MIN" ]; then
	echo "You must have at least ${DISK_MIN}GB of available storage to install EOSIO."
	echo "Exiting now."
	exit 1
fi

printf "\\n"

printf "${COLOR_CYAN}[Checking xcode-select installation]${COLOR_NC}\\n"
if ! XCODESELECT=$( command -v xcode-select ); then printf " - XCode must be installed in order to proceed!\\n" && exit 1;
else printf " - XCode installation found @ ${XCODESELECT}\\n"; fi

printf "${COLOR_CYAN}[Checking Ruby installation]${COLOR_NC}\\n"
if ! RUBY=$( command -v ruby ); then printf " - Ruby must be installed in order to proceed!\\n" && exit 1;
else printf " - Ruby installation found @ ${RUBY}\\n"; fi

printf "${COLOR_CYAN}[Checking HomeBrew installation]${COLOR_NC}\\n"
if ! BREW=$( command -v brew ); then
	while true; do
		[[ $NONINTERACTIVE == false ]] && read -p "${COLOR_YELLOW}Do you wish to install HomeBrew? (y/n)?${COLOR_NC} " NONINTERACTIVE
		case $NONINTERACTIVE in
			"" ) echo "What would you like to do?";;
			0 | true | [Yy]* )
				execute "${XCODESELECT}" --install
				if ! execute "${RUBY}" -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"; then
					echo "Unable to install homebrew at this time." && exit 1;
				else BREW=$( command -v brew ); fi
			break;;
			1 | false | [Nn]* ) echo "${COLOR_RED}[User aborted required homebrew installation]${COLOR_NC}"; exit 1;;
			* ) echo "Please type 'y' for yes or 'n' for no.";;
		esac
	done
else
	printf " - HomeBrew installation found @ ${BREW}\\n"
fi

printf "\\n${COLOR_CYAN}[Checking HomeBrew dependencies]${COLOR_NC}\\n"
var_ifs="${IFS}"
IFS=","
while read -r name tester testee uri; do
	if [ $tester $testee ]; then
		printf " - ${name} found!\\n"
		continue
	fi
	# resolve conflict with homebrew glibtool and apple/gnu installs of libtool
	if [ "${testee}" == "/usr/local/bin/glibtool" ]; then
		if [ "${tester}" "/usr/local/bin/libtool" ]; then
			printf " - ${name} found!\\n"
			continue
		fi
	fi
	DEPS=$DEPS"${name},"
	printf " - ${name} ${COLOR_RED}NOT${COLOR_NC} found.\\n"
	(( COUNT++ ))
done < "${REPO_ROOT}/scripts/eosio_build_darwin_deps"
IFS="${var_ifs}"

if [ ! -d /usr/local/Frameworks ]; then
	printf "\\n${COLOR_YELLOW}/usr/local/Frameworks is necessary to brew install python@3. Run the following commands as sudo and try again:${COLOR_NC}\\n"
	printf "sudo mkdir /usr/local/Frameworks && sudo chown $(whoami):admin /usr/local/Frameworks\\n\\n"
	exit 1;
fi

printf "\n"

if [ $COUNT -gt 1 ]; then
	while true; do
		[[ $NONINTERACTIVE == false ]] && read -p "${COLOR_YELLOW}Do you wish to install missing dependencies? (y/n)${COLOR_NC} " PROCEED
		case $PROCEED in
			"" ) echo "What would you like to do?";;
			0 | true | [Yy]* )
				execute "${XCODESELECT}" --install 2>/dev/null;
				while true; do
					[[ $NONINTERACTIVE != 1 ]] && read -p "${COLOR_YELLOW}Do you wish to update homebrew packages first? (y/n)${COLOR_NC} " PROCEED
					case $PROCEED in
						"" ) echo "What would you like to do?";;
						0 | true | [Yy]* ) execute brew update; break;;
						1 | false | [Nn]* ) echo "Proceeding without update!"; break;;
						* ) echo "Please type 'y' for yes or 'n' for no.";;
					esac
				done
				execute brew tap eosio/eosio
				printf "${COLOR_GREEN}[Installing Dependencies]${COLOR_NC}\\n"
				OIFS="$IFS"
				IFS=$','
				for DEP in $DEPS; do
					# Eval to support string/arguments with $DEP
					execute $BREW install $DEP
				done
				IFS="$OIFS"
			break;;
			1 | false | [Nn]* ) echo "User aborting installation of required dependencies, Exiting now."; exit;;
			* ) echo "Please type 'y' for yes or 'n' for no.";;
		esac
	done
else
	printf " - No required Home Brew dependencies to install.\\n"
fi

printf "\\n"

export CPATH="$(python-config --includes | awk '{print $1}' | cut -dI -f2):$CPATH" # Boost has trouble finding pyconfig.h
printf "${COLOR_CYAN}[Checking Boost $( echo $BOOST_VERSION | sed 's/_/./g' ) library installation]${COLOR_NC}\\n"
BOOSTVERSION=$( grep "#define BOOST_VERSION" "$HOME/opt/boost/include/boost/version.hpp" 2>/dev/null | tail -1 | tr -s ' ' | cut -d\  -f3 || true )
if [ "${BOOSTVERSION}" != "${BOOST_VERSION_MAJOR}0${BOOST_VERSION_MINOR}0${BOOST_VERSION_PATCH}" ]; then
	printf "Installing Boost library...\\n"
	execute bash -c "curl -LO https://dl.bintray.com/boostorg/release/$BOOST_VERSION_MAJOR.$BOOST_VERSION_MINOR.$BOOST_VERSION_PATCH/source/boost_$BOOST_VERSION.tar.bz2
	&& tar -xjf boost_$BOOST_VERSION.tar.bz2
	&& cd $BOOST_ROOT
	&& ./bootstrap.sh --prefix=$BOOST_ROOT
	&& ./b2 -q -j$(sysctl -in machdep.cpu.core_count) --with-iostreams --with-date_time --with-filesystem
	                                                  --with-system --with-program_options --with-chrono --with-test install
	&& cd ..
	&& rm -f boost_$BOOST_VERSION.tar.bz2
	&& rm -rf $BOOST_LINK_LOCATION
	&& ln -s $BOOST_ROOT $BOOST_LINK_LOCATION"
	printf " - Boost library successfully installed @ ${BOOST_ROOT}.\\n"
else
	printf " - Boost library found with correct version @ ${BOOST_ROOT}.\\n"
fi

printf "\\n"

printf "${COLOR_CYAN}[Checking MongoDB installation]${COLOR_NC}\\n"
if [ ! -d $MONGODB_ROOT ]; then
	printf "Installing MongoDB into ${MONGODB_ROOT}...\\n"
	execute bash -c "curl -OL https://fastdl.mongodb.org/osx/mongodb-osx-ssl-x86_64-$MONGODB_VERSION.tgz
	&& tar -xzf mongodb-osx-ssl-x86_64-$MONGODB_VERSION.tgz
	&& mv $SRC_LOCATION/mongodb-osx-x86_64-$MONGODB_VERSION $MONGODB_ROOT
	&& touch $MONGODB_LOG_LOCATION/mongod.log
	&& rm -f mongodb-osx-ssl-x86_64-$MONGODB_VERSION.tgz
	&& cp -f $REPO_ROOT/scripts/mongod.conf $MONGODB_CONF
	&& mkdir -p $MONGODB_DATA_LOCATION
	&& rm -rf $MONGODB_LINK_LOCATION
	&& rm -rf $BIN_LOCATION/mongod
	&& ln -s $MONGODB_ROOT $MONGODB_LINK_LOCATION
	&& ln -s $MONGODB_LINK_LOCATION/bin/mongod $BIN_LOCATION/mongod"
	printf " - MongoDB successfully installed @ ${MONGODB_ROOT}\\n"
else
	printf " - MongoDB found with correct version @ ${MONGODB_ROOT}.\\n"
fi
printf "${COLOR_CYAN}[Checking MongoDB C driver installation]${COLOR_NC}\\n"
if [ ! -d $MONGO_C_DRIVER_ROOT ]; then
	printf "Installing MongoDB C driver...\\n"
	execute bash -c "curl -LO https://github.com/mongodb/mongo-c-driver/releases/download/$MONGO_C_DRIVER_VERSION/mongo-c-driver-$MONGO_C_DRIVER_VERSION.tar.gz
	&& tar -xzf mongo-c-driver-$MONGO_C_DRIVER_VERSION.tar.gz
	&& cd mongo-c-driver-$MONGO_C_DRIVER_VERSION
	&& mkdir -p cmake-build
	&& cd cmake-build
	&& $CMAKE -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME -DENABLE_BSON=ON -DENABLE_SSL=DARWIN -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_STATIC=ON ..
	&& make -j"${JOBS}"
	&& make install
	&& cd ../..
	&& rm mongo-c-driver-$MONGO_C_DRIVER_VERSION.tar.gz"
	printf " - MongoDB C driver successfully installed @ ${MONGO_C_DRIVER_ROOT}.\\n"
else
	printf " - MongoDB C driver found with correct version @ ${MONGO_C_DRIVER_ROOT}.\\n"
fi
printf "${COLOR_CYAN}[Checking MongoDB C++ driver installation]${COLOR_NC}\\n"
if [ "$(grep "Version:" $HOME/lib/pkgconfig/libmongocxx-static.pc 2>/dev/null | tr -s ' ' | awk '{print $2}' || true)" != $MONGO_CXX_DRIVER_VERSION ]; then
	printf "Installing MongoDB C++ driver...\\n"
	bash -c "curl -L https://github.com/mongodb/mongo-cxx-driver/archive/r$MONGO_CXX_DRIVER_VERSION.tar.gz -o mongo-cxx-driver-r$MONGO_CXX_DRIVER_VERSION.tar.gz
	&& tar -xzf mongo-cxx-driver-r${MONGO_CXX_DRIVER_VERSION}.tar.gz
	&& cd mongo-cxx-driver-r$MONGO_CXX_DRIVER_VERSION/build
	&& $CMAKE -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME ..
	&& make -j"${JOBS}" VERBOSE=1
	&& make install
	&& cd ../..
	&& rm -f mongo-cxx-driver-r$MONGO_CXX_DRIVER_VERSION.tar.gz"
	printf " - MongoDB C++ driver successfully installed @ ${MONGO_CXX_DRIVER_ROOT}.\\n"
else
	printf " - MongoDB C++ driver found with correct version @ ${MONGO_CXX_DRIVER_ROOT}.\\n"
fi

printf "\\n"

# We install llvm into /usr/local/opt using brew install llvm@4
printf "${COLOR_CYAN}[Checking LLVM 4 support}${COLOR_NC}\\n"
if [ ! -d $LLVM_ROOT ]; then
	execute ln -s /usr/local/opt/llvm@4 $LLVM_ROOT
	printf " - LLVM successfully linked from /usr/local/opt/llvm@4 to ${LLVM_ROOT}\\n"
else
	printf " - LLVM found @ ${LLVM_ROOT}.\\n"
fi

printf "\\n"
execute cd ..

function print_instructions() {
	return 0
}
# Obtain OS NAME, and VERSION
. /etc/os-release

DISK_INSTALL=$( df -h . | tail -1 | tr -s ' ' | cut -d\  -f1 )
DISK_TOTAL_KB=$( df . | tail -1 | awk '{print $2}' )
DISK_AVAIL_KB=$( df . | tail -1 | awk '{print $4}' )
DISK_TOTAL=$(( DISK_TOTAL_KB / 1048576 ))
DISK_AVAIL=$(( DISK_AVAIL_KB / 1048576 ))

if [[ "${NAME}" == "Amazon Linux AMI" ]]; then # Amazonlinux1
	DEP_ARRAY=( 
		sudo procps util-linux which gcc72 gcc72-c++ autoconf automake libtool make doxygen graphviz \
		bzip2 bzip2-devel openssl-devel gmp gmp-devel libstdc++72 python27 python27-devel python36 python36-devel \
		libedit-devel ncurses-devel swig wget file libcurl-devel libusb1-devel
	)
else # Amazonlinux2
	DEP_ARRAY=( 
		git procps-ng util-linux gcc gcc-c++ autoconf automake libtool make bzip2 \
		bzip2-devel openssl-devel gmp-devel libstdc++ libcurl-devel libusbx-devel \
		python3 python3-devel python-devel libedit-devel doxygen graphviz 
	)
fi

( [[ "${NAME}" == "Amazon Linux AMI" ]] && [[ "$(echo ${VERSION} | sed 's/.//g')" -gt 201709 ]] ) && printf "You must be running Amazon Linux 2017.09 or higher to install EOSIO.\\n" && exit 1
[[ "${DISK_AVAIL}" -lt "${DISK_MIN}" ]] && printf "You must have at least %sGB of available storage to install EOSIO.\\n" "${DISK_MIN}" && exit 1

printf "${COLOR_CYAN}[Checking YUM installation]${COLOR_NC}\\n"
if ! YUM=$( command -v yum 2>/dev/null ); then printf " - YUM must be installed to compile EOS.IO.\\n" && exit 1
else printf "Yum installation found at ${YUM}.\\n"; fi

[[ $NONINTERACTIVE == false ]] && read -p "${COLOR_YELLOW}Do you wish to update YUM repositories? (y/n)?${COLOR_NC} " PROCEED
while true; do
	case $PROCEED in
		"" ) echo "What would you like to do?";;
		0 | true | [Yy]* )
			if ! execute sudo $YUM -y update; then
				printf " - ${COLOR_RED}YUM update failed.${COLOR_NC}\\n"
				exit 1;
			else
				printf " - ${COLOR_GREEN}YUM update complete.${COLOR_NC}\\n"
			fi
		break;;
		1 | false | [Nn]* ) echo " - Proceeding without update!"; break;;
		* ) echo "Please type 'y' for yes or 'n' for no.";;
	esac
done
printf "${COLOR_CYAN}[Checking RPM for installed dependencies]${COLOR_NC}\\n"
while read -r name tester testee uri; do
	if [ $tester $testee ] && [[ $DRYRUN == false ]]; then # DRYRUN TO SUPPORT TESTS
		printf " - ${name} ${COLOR_GREEN}found!${COLOR_NC}\\n"
		continue
	fi
	# resolve conflict with homebrew glibtool and apple/gnu installs of libtool
	if [[ "${testee}" == "/usr/local/bin/glibtool" ]]; then
		if [ "${tester}" "/usr/local/bin/libtool" ]; then
			printf " - ${name} ${COLOR_GREEN}found!${COLOR_NC}\\n"
			continue
		fi
	fi
	DEPS=$DEPS"${name},"
	printf " - ${name} ${COLOR_RED}NOT${COLOR_NC} found.\\n"
	(( COUNT++ ))
done < "${REPO_ROOT}/scripts/eosio_build_amazonlinux1_deps"

exit
for DEP in ${DEP_ARRAY[@]}; do

	pkg=$( execute "rpm -qi ${DEP_ARRAY[$i]} 2>/dev/null | grep Name" )
	$VERBOSE && echo "  $pkg"
	if $DRYRUN && [[ -z $pkg ]]; then
		DEP=$DEP" ${DEP_ARRAY[$i]} "
		DISPLAY="${DISPLAY}${COUNT}. ${DEP_ARRAY[$i]}\\n"
		printf " - Package %s ${COLOR_RED} NOT ${COLOR_NC} found!\\n" "${DEP_ARRAY[$i]}"
		(( COUNT++ ))
	else
		printf " - Package %s ${COLOR_GREEN}found!${COLOR_NC}\\n" "${DEP_ARRAY[$i]}"
		continue
	fi
done
if [ "${COUNT}" -gt 1 ]; then
	[[ $NONINTERACTIVE == false ]] && read -p "${COLOR_YELLOW}Do you wish to install missing dependencies? (y/n)?${COLOR_NC} " PROCEED
	while true; do
		case $PROCEED in
			"" ) echo "What would you like to do?";;
			0 | true | [Yy]* )
				if ! execute sudo $YUM -y install ${DEP}; then
					printf " ${COLOR_RED}- YUM dependency installation failed!${COLOR_NC}\\n"
					exit 1;
				else
					printf " ${COLOR_GREEN}- YUM dependencies installed successfully.${COLOR_NC}\\n"
				fi
			;;
			1 | false | [Nn]* ) echo " ${COLOR_RED}- User aborting installation of required dependencies.${COLOR_NC}"; exit;;
			* ) echo "Please type 'y' for yes or 'n' for no.";;
		esac
	done
else
	printf " - No required YUM dependencies to install.\\n"
fi

# util-linux includes lscpu
# procps includes free -m
MEM_MEG=$( free -m | sed -n 2p | tr -s ' ' | cut -d\  -f2 )
CPU_SPEED=$( lscpu | grep "MHz" | tr -s ' ' | cut -d\  -f3 | cut -d'.' -f1 )
CPU_CORE=$( nproc )
MEM_GIG=$(( ((MEM_MEG / 1000) / 2) ))
export JOBS=$(( MEM_GIG > CPU_CORE ? CPU_CORE : MEM_GIG ))

printf "\\nOS name: %s\\n" "${OS_NAME}"
printf "OS Version: %s\\n" "${OS_VER}"
printf "CPU speed: %sMhz\\n" "${CPU_SPEED}"
printf "CPU cores: %s\\n" "${CPU_CORE}"
printf "Physical Memory: %sMgb\\n" "${MEM_MEG}"
printf "Disk space total: %sGb\\n" "${DISK_TOTAL}"
printf "Disk space available: %sG\\n" "${DISK_AVAIL}"

[ "${MEM_MEG}" -lt 7000 ] && printf "Your system must have 7 or more Gigabytes of physical memory installed.\\n" && exit 1

printf "\\n"

printf "${COLOR_CYAN}[Checking CMAKE installation]${COLOR_NC}\\n"
if [[ -z "${CMAKE}" ]]; then
	printf "Installing CMAKE...\\n"
	execute bash -c "curl -LO https://cmake.org/files/v${CMAKE_VERSION_MAJOR}.${CMAKE_VERSION_MINOR}/cmake-${CMAKE_VERSION}.tar.gz \
	&& tar -xzf cmake-${CMAKE_VERSION}.tar.gz \
	&& cd cmake-${CMAKE_VERSION} \
	&& ./bootstrap --prefix=${HOME} \
	&& make -j${JOBS} \
	&& make install \
	&& cd .. \
	&& rm -f cmake-${CMAKE_VERSION}.tar.gz"
	printf " - CMAKE successfully installed @ ${CMAKE} \\n"
else
	printf " - CMAKE found @ ${CMAKE}.\\n"
fi

printf "\\n"

printf "${COLOR_CYAN}[Checking Boost $( echo $BOOST_VERSION | sed 's/_/./g' ) library installation]${COLOR_NC}\\n"
BOOSTVERSION=$( grep "#define BOOST_VERSION" "$HOME/opt/boost/include/boost/version.hpp" 2>/dev/null | tail -1 | tr -s ' ' | cut -d\  -f3 || true )
if [[ "${BOOSTVERSION}" != "${BOOST_VERSION_MAJOR}0${BOOST_VERSION_MINOR}0${BOOST_VERSION_PATCH}" ]]; then
	printf "Installing Boost library...\\n"
	execute bash -c "curl -LO https://dl.bintray.com/boostorg/release/$BOOST_VERSION_MAJOR.$BOOST_VERSION_MINOR.$BOOST_VERSION_PATCH/source/boost_$BOOST_VERSION.tar.bz2 \
	&& tar -xjf boost_$BOOST_VERSION.tar.bz2 \
	&& cd $BOOST_ROOT \
	&& ./bootstrap.sh --prefix=$BOOST_ROOT \
	&& ./b2 -q -j$(sysctl -in machdep.cpu.core_count) --with-iostreams --with-date_time --with-filesystem \
	                                                  --with-system --with-program_options --with-chrono --with-test install \
	&& cd .. \
	&& rm -f boost_$BOOST_VERSION.tar.bz2 \
	&& rm -rf $BOOST_LINK_LOCATION \
	&& ln -s $BOOST_ROOT $BOOST_LINK_LOCATION"
	printf " - Boost library successfully installed @ ${BOOST_ROOT}.\\n"
else
	printf " - Boost library found with correct version @ ${BOOST_ROOT}.\\n"
fi

printf "\\n"

printf "${COLOR_CYAN}[Checking MongoDB installation]${COLOR_NC}\\n"
if [[ ! -d $MONGODB_ROOT ]]; then
	printf "Installing MongoDB into ${MONGODB_ROOT}...\\n"
	execute bash -c "curl -OL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-$MONGODB_VERSION.tgz \
	&& tar -xzf mongodb-linux-x86_64-amazon-$MONGODB_VERSION.tgz \
	&& mv $SRC_LOCATION/mongodb-linux-x86_64-amazon-$MONGODB_VERSION $MONGODB_ROOT \
	&& touch $MONGODB_LOG_LOCATION/mongod.log \
	&& rm -f mongodb-linux-x86_64-amazon-$MONGODB_VERSION.tgz \
	&& cp -f $REPO_ROOT/scripts/mongod.conf $MONGODB_CONF \
	&& mkdir -p $MONGODB_DATA_LOCATION \
	&& rm -rf $MONGODB_LINK_LOCATION \
	&& rm -rf $BIN_LOCATION/mongod \
	&& ln -s $MONGODB_ROOT $MONGODB_LINK_LOCATION \
	&& ln -s $MONGODB_LINK_LOCATION/bin/mongod $BIN_LOCATION/mongod"
	printf " - MongoDB successfully installed @ ${MONGODB_ROOT}.\\n"
else
	printf " - MongoDB found with correct version @ ${MONGODB_ROOT}.\\n"
fi
printf "${COLOR_CYAN}[Checking MongoDB C driver installation]${COLOR_NC}\\n"
if [[ ! -d $MONGO_C_DRIVER_ROOT ]]; then
	printf "Installing MongoDB C driver...\\n"
	execute bash -c "curl -LO https://github.com/mongodb/mongo-c-driver/releases/download/$MONGO_C_DRIVER_VERSION/mongo-c-driver-$MONGO_C_DRIVER_VERSION.tar.gz \
	&& tar -xzf mongo-c-driver-$MONGO_C_DRIVER_VERSION.tar.gz \
	&& cd mongo-c-driver-$MONGO_C_DRIVER_VERSION \
	&& mkdir -p cmake-build \
	&& cd cmake-build \
	&& $CMAKE -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME -DENABLE_BSON=ON -DENABLE_SSL=OPENSSL -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_STATIC=ON .. \
	&& make -j"${JOBS}" \
	&& make install \
	&& cd ../.. \
	&& rm mongo-c-driver-$MONGO_C_DRIVER_VERSION.tar.gz"
	printf " - MongoDB C driver successfully installed @ ${MONGO_C_DRIVER_ROOT}.\\n"
else
	printf " - MongoDB C driver found with correct version @ ${MONGO_C_DRIVER_ROOT}.\\n"
fi
printf "${COLOR_CYAN}[Checking MongoDB C++ driver installation]${COLOR_NC}\\n"
if [[ ! -d $MONGO_CXX_DRIVER_ROOT ]]; then
	printf "Installing MongoDB C++ driver...\\n"
	execute bash -c "curl -L https://github.com/mongodb/mongo-cxx-driver/archive/r$MONGO_CXX_DRIVER_VERSION.tar.gz -o mongo-cxx-driver-r$MONGO_CXX_DRIVER_VERSION.tar.gz \
	&& tar -xzf mongo-cxx-driver-r${MONGO_CXX_DRIVER_VERSION}.tar.gz \
	&& cd mongo-cxx-driver-r$MONGO_CXX_DRIVER_VERSION/build \
	&& $CMAKE -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME .. \
	&& make -j"${JOBS}" VERBOSE=1 \
	&& make install \
	&& cd ../.. \
	&& rm -f mongo-cxx-driver-r$MONGO_CXX_DRIVER_VERSION.tar.gz"
	printf " - MongoDB C++ driver successfully installed @ ${MONGO_CXX_DRIVER_ROOT}.\\n"
else
	printf " - MongoDB C++ driver found with correct version @ ${MONGO_CXX_DRIVER_ROOT}.\\n"
fi

printf "\\n"

printf "${COLOR_CYAN}[Checking LLVM 4 support}${COLOR_NC}\\n"
if [[ ! -d $LLVM_ROOT ]]; then
	printf "Installing LLVM 4...\\n"
	execute bash -c "cd ../opt \
	&& git clone --depth 1 --single-branch --branch $LLVM_VERSION https://github.com/llvm-mirror/llvm.git llvm && cd llvm \
	&& mkdir build \
	&& cd build \
	&& $CMAKE -G \"Unix Makefiles\" -DCMAKE_INSTALL_PREFIX=\"${LLVM_ROOT}\" -DLLVM_TARGETS_TO_BUILD=\"host\" -DLLVM_BUILD_TOOLS=false -DLLVM_ENABLE_RTTI=1 -DCMAKE_BUILD_TYPE=\"Release\" .. \
	&& make -j$JOBS \
	&& make install \
	&& cd ../.."
	printf " - LLVM successfully installed @ ${LLVM_ROOT}\\n"
else
	printf " - LLVM found @ ${LLVM_ROOT}.\\n"
fi

printf "\\n"

function print_instructions() {
	return 0
}

#! /bin/bash

# NOTE: This requires bash since RUBY_CONFIGURE_QUALS is an array, and sh doesn't
#       support arrays. If we ever port to UNIX, we'll need to handle this in a
#       different way (or make sure bash is on our build systems).

#
# Usage: buildRuby.sh <parameter>
#
#   Parameter may be one of:
#       "110": Build for SSL v1.1.0
#       "100": Build for SSL v1.0.0
#       blank: Build for the local system
#       test:  Build for test purposes
#       

set -e

RUBY_BUILD_TYPE=$1

# The sudo command will not preserve many environment variables, and we require
# that at least LD_LIBRARY_PATH is preserved to build with different versions
# of SSL. The "elevate" command will use SUDO, but will preserve specific
# environment variables.

elevate()
{
    local ENV_FILE=/tmp/$USER-elevate-$$.env
    local SUDO_FILE=/tmp/$USER-elevate-$$.sh

    rm -f $ENV_FILE $SUDO_FILE

    # Write out the environment variables to preserve
    echo "export LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH\"" >> $ENV_FILE

    # Write out the actual script that will be sudo elevated
    echo "#! /bin/bash" >> $SUDO_FILE
    echo >> $SUDO_FILE
    echo "source $ENV_FILE" >> $SUDO_FILE
    echo $@ >> $SUDO_FILE

    # Now run the command to elevate
    chmod +x $SUDO_FILE
    sudo $SUDO_FILE
    exit_status=$?

    # Cleanup
    rm -f $ENV_FILE $SUDO_FILE

    return $exit_status
}

# Helper script to build Ruby properly for OMS agent
# Also builds fluentd since it lives under the Ruby directory

BASE_DIR=`(cd ..; pwd -P)`
OMS_AGENTDIR=/opt/microsoft/omsagent

PATCHES_SRCDIR=${BASE_DIR}/source/ext/patches
RUBY_SRCDIR=${BASE_DIR}/source/ext/ruby
FLUENTD_DIR=${BASE_DIR}/source/ext/fluentd

# Has configure script been run?

if [ ! -f ${BASE_DIR}/build/config.mak ]; then
    echo "Fatal: configure script not run, please run configure to build Ruby" >& 2
    exit 1
fi

. ${BASE_DIR}/build/config.mak

if [ -z "${BUILD_CONFIGURATION}" ]; then
    echo "Fatal: Configuration file error; \$BUILD_CONFIGURATION not properly defined" >& 2
    exit 1
fi

# Modify Ruby build configuration as necessary for SSL version
# (Only one parameter is valid for us; verify this)

if [ $# -gt 1 ]; then
    echo "$0: Invalid option (see comments for usage)" >& 2
    exit 1
fi

RUNNING_FOR_TEST=0

case $RUBY_BUILD_TYPE in
    test)
        RUBY_CONFIGURE_QUALS=( "${RUBY_CONFIGURE_QUALS[@]}" "${RUBY_CONFIGURE_QUALS_TESTINS}" )
        RUNNING_FOR_TEST=1
	;;

    100)
        INT_APPEND_DIR="/${RUBY_BUILD_TYPE}"
        RUBY_CONFIGURE_QUALS=( "${RUBY_CONFIGURE_QUALS_100[@]}" "${RUBY_CONFIGURE_QUALS[@]}" "${RUBY_CONFIGURE_QUALS_SYSINS}" )

        export LD_LIBRARY_PATH=$SSL_100_LIBPATH:$LD_LIBRARY_PATH
        export PKG_CONFIG_PATH=${SSL_100_LIBPATH}/pkgconfig:$PKG_CONFIG_PATH
        ;;

    110)
        INT_APPEND_DIR="/${RUBY_BUILD_TYPE}"
        RUBY_CONFIGURE_QUALS=( "${RUBY_CONFIGURE_QUALS_110[@]}" "${RUBY_CONFIGURE_QUALS[@]}" "${RUBY_CONFIGURE_QUALS_SYSINS}" )

        export LD_LIBRARY_PATH=$SSL_110_LIBPATH:$LD_LIBRARY_PATH
        export PKG_CONFIG_PATH=${SSL_110_LIBPATH}/pkgconfig:$PKG_CONFIG_PATH
        ;;

    *)
        INT_APPEND_DIR=""
        RUBY_CONFIGURE_QUALS=( "${RUBY_CONFIGURE_QUALS[@]}" "${RUBY_CONFIGURE_QUALS_SYSINS}" )

        if [ -n "$RUBY_BUILD_TYPE" ]; then
            echo "Invalid parameter passed (${RUBY_BUILD_TYPE}): Must be test, 100, 110 or blank" >& 2
            exit 1
        fi
esac

# There are multiple entires on the configure line; just get the one we need
RUBY_DESTDIR=`echo "${RUBY_CONFIGURE_QUALS[@]}" | sed "s/ /\n/g" | grep -- "--prefix=" | cut -d= -f2`

echo "Beginning Ruby build process ..."
echo "  Build directory:   ${BASE_DIR}"
echo "  Ruby sources:      ${RUBY_SRCDIR}"
echo "  Ruby destination:  ${RUBY_DESTDIR}"
echo "  Configuration:     ${RUBY_CONFIGURE_QUALS[@]}"

# Did we pick up Ruby destintion directory properly?

if [ -z "${RUBY_DESTDIR}" ]; then
    echo "Fatal: Configuration file error; \$RUBY_CONFIGURATION_QUALS not properly defined" >& 2
    exit 1
fi

# Do we have the Ruby source code?

if [ ! -d ${RUBY_SRCDIR} ]; then
    echo "Fatal: Ruby source code not found at ${RUBY_SRCDIR}" >& 2
    exit 1
fi

# Our build procedure temporarily builds Ruby in it's home location in order to
# populate it with the proper gemfiles. Additionally, we want to use the "real"
# version of Ruby to do this to protect against Ruby version differences in how
# that is handled.

if [ -d ${OMS_AGENTDIR} -a ${RUNNING_FOR_TEST} -eq 0 ]; then
    echo "FATAL: OMS agent is already installed at '${OMS_AGENTDIR}'! Must remove agent to build agent ..." >& 2
    exit 1
fi

# Clean the version of Ruby from any existing files that aren't part of source
# control

cd ${RUBY_SRCDIR}
sudo rm -rf ${RUBY_SRCDIR}/.ext
git clean -dfx

# Restore the configure script

cp ${PATCHES_SRCDIR}/ruby/configure ${RUBY_SRCDIR}

# Configure and build Ruby

cd ${RUBY_SRCDIR}
echo "========================= Performing Running Ruby configure"
echo " Building Ruby with configuration: ${RUBY_CONFIGURE_QUALS[@]} ..."
touch configure
./configure "${RUBY_CONFIGURE_QUALS[@]}"

#
# "Fix" the source tree.
#
# Ruby build may modify a few of it's files. Deal with it.
#

echo "========================= Performing Repairing Ruby sources"

# RUBY_REPAIR_LIST is set reletive to the Ruby source directory
RUBY_REPAIR_LIST="enc/unicode/9.0.0/name2ctype.h"

cd ${RUBY_SRCDIR}
git checkout -- ${RUBY_REPAIR_LIST}

#
# Now build Ruby ...
#

echo "========================= Performing Building Ruby"
make

# Note: Ruby can fail unit tests on older platforms (like Suse 10).
# Since we moved to an alternate platform, continue to fail on test errors.
echo "Running Ruby unit tests ..."
make test

echo "Running Ruby install ..."
elevate make install

export PATH=${RUBY_DESTDIR}/bin:$PATH

if [ $RUNNING_FOR_TEST -eq 1 ]; then
    echo "Installing Metaclass and Mocha (for UnitTest) into Ruby ..."
    elevate ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/metaclass-0.0.4.gem
    elevate ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/mocha-1.8.0.gem
fi

echo "Installing Bundler into Ruby ..."
elevate ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/bundler-1.10.6.gem

echo "Installing Builder into Ruby ..."
elevate ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/builder-3.2.3.gem

echo "Installing Gyoku into Ruby ..."
elevate ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/gyoku-1.3.1.gem

echo "Installing ISO8601 into Ruby ..."
elevate ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/iso8601-0.12.1.gem

# Now do what we need for FluentD

cd ${FLUENTD_DIR}

if [ ! -d ${FLUENTD_DIR}/vendor/cache ]; then
    echo "========================= Performing Fetching FluentD dependencies for Ruby"
    bundle install
    bundle package --all
    echo "*** Be sure to check all files in 'vendor/cache' into TFS ***"
fi

echo "========================= Performing Building FluentD"
cd ${FLUENTD_DIR}
bundle install --local
bundle exec rake build
elevate ${RUBY_DESTDIR}/bin/gem install pkg/fluentd-0.12.40.gem

echo "========================= Performing Stripping Binaries"
sudo find ${RUBY_DESTDIR} -name \*.so -print -exec strip {} \;
sudo strip ${RUBY_DESTDIR}/bin/ruby

if [ $RUNNING_FOR_TEST -eq 0 ]; then
    echo "========================= Performing Moving Ruby to intermediate directory"

    # Variable ${INT_APPEND_DIR} will either be blank, or something like "/100"
    mkdir -p ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}${INT_APPEND_DIR}
    rm -rf ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}${INT_APPEND_DIR}/ruby
    sudo mv ${RUBY_DESTDIR} ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}${INT_APPEND_DIR}
    sudo chown -R `id -u`:`id -g` ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}${INT_APPEND_DIR}
    sudo rm -rf ${OMS_AGENTDIR}

    # Pacify Make (Make doesn't know that the generated Ruby directory can vary)
    mkdir -p ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}/ruby
fi

exit 0

#! /bin/sh

set -e

# Helper script to build Ruby properly for OMS agent
# Also builds fluentd since it lives under the Ruby directory

BASE_DIR=`(cd ..; pwd -P)`
OMS_AGENTDIR=/opt/microsoft/omsagent

RUBY_SRCDIR=${BASE_DIR}/source/ext/ruby
FLUENTD_DIR=${BASE_DIR}/source/ext/fluentd

# Has configure script been run?

if [ ! -f ${BASE_DIR}/build/config.mak ]; then
    echo "Fatal: configure script not run, please run configure to build Ruby" >& 2
    exit 1
fi

. ${BASE_DIR}/build/config.mak

# There may be multiple entires on the configure line; just get the one we need
RUBY_DESTDIR=`echo $RUBY_CONFIGURE_QUALS | sed "s/ /\n/g" | grep -- "--prefix=" | cut -d= -f2`

echo "Beginning Ruby build process ..."
echo "  Build directory:   ${BASE_DIR}"
echo "  Ruby sources:      ${RUBY_SRCDIR}"
echo "  Ruby destination:  ${RUBY_DESTDIR}"

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

if [ -d ${OMS_AGENTDIR} ]; then
    echo "FATAL: OMS agent is already installed at '${OMS_AGENTDIR}'! Must remove agent to build agent ..." >& 2
    exit 1
fi

# Clean the version of Ruby from any existing files that aren't part of source
# control

sudo rm -rf ${RUBY_SRCDIR}/.ext
find ${RUBY_SRCDIR} -type f -perm -u+w -exec rm -f {} \;
find ${FLUENTD_DIR} -type f -perm -u+w -exec rm {} \;

cd ${RUBY_SRCDIR}
echo "========================= Performing Running Ruby configure"
chmod u+x configure tool/ifchange
touch configure
echo " Building Ruby with configuration: ${RUBY_CONFIGURE_QUALS} ..."
./configure ${RUBY_CONFIGURE_QUALS}

#
# "Fix" the source tree. Ruby build may modify a few of it's files. Deal with it.
#
# This occurs becuase 'git' allows files to be writable while still under source
# control, but 'tfs' does not.
#

echo "========================= Performing Repairing Ruby sources"
RUBY_REPAIR_LIST="${RUBY_SRCDIR}/enc/unicode/name2ctype.h ${RUBY_SRCDIR}/enc/jis/props.h"

tf get -force ${RUBY_REPAIR_LIST}
chmod u+w ${RUBY_REPAIR_LIST}

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
sudo make install

export PATH=${RUBY_DESTDIR}/bin:$PATH

echo "Installing Bundler into Ruby ..."
sudo ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/bundler-1.10.6.gem

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
sudo ${RUBY_DESTDIR}/bin/gem install pkg/fluentd-0.12.14.gem

echo "========================= Performing Moving Ruby to intermediate directory"
mkdir -p ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}
sudo rm -rf ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}/ruby
sudo mv ${RUBY_DESTDIR} ${BASE_DIR}/intermediate/${BUILD_CONFIGURATION}
sudo rm -rf ${OMS_AGENTDIR}

exit 0

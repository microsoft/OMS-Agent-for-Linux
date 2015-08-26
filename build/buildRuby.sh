#! /bin/sh

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

RUBY_DESTDIR=`echo $RUBY_CONFIGURE_QUALS | cut -f2 -d=`

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

echo "========================= Performing Building Ruby"
make

echo "Running Ruby unit tests ..."
make test

echo "Running Ruby install ..."
sudo make install

export PATH=${RUBY_DESTDIR}/bin:$PATH

echo "Installing Bundler into Ruby ..."
sudo ${RUBY_DESTDIR}/bin/gem install bundler

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

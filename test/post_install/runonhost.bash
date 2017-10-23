#!/bin/bash
# 345678901234567890123456789012345678901234567890123456789012345678901234567890

# runonhost.sh - To run install tests interactively on the host under test.

export MDRTB_TOP=$(dirname $0)
source $MDRTB_TOP/mdrtb.conf

# ### Initializations

_iterations=$1

# Ruby helpers
RUBY=/opt/microsoft/omsagent/ruby/bin/ruby

/opt/microsoft/omsagent/ruby/bin/gem install minitest

if [[ ! $_iterations =~ ^[0-9][0-9]*$ ]]
then
    (( _iterations = 1 ))
fi

# ### Main

pushd $MDRTB_TOP
i=0
echo "Starting runs at $(date)"
while (( i < _iterations ))
do
    $RUBY $MDRTB_TOP/service_control_installtest.rb
    (( i = i + 1 ))
    echo "Run $i done at $(date)"
done
popd

# 345678901234567890123456789012345678901234567890123456789012345678901234567890
# End of runonhost.sh

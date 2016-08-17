## How to add a new gem to omsagent install bundle

In order to add a new Ruby gem into OMSAgent bundle when you have the new_gem_name.gem file on you local system you need to follow these steps:
1. Update the private branch:
* Clone Microsoft/Build-OMS-Agent-for-Linux github repo
* Copy the new_gem_name.gem to Build-OMS-Agent-for-Linux//omsagent/source\ext\gems folder.
* Navigate to Build-OMS-Agent-for-Linux//omsagent/build and put modified commands in buildRuby.sh
(Example ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/new_gem_name.gem)
* Run buildRuby.sh 100
* It will build the new changes for ruby under intermediate/*/100/Ruby.
* Run ../installer/scripts/genRubyInstaller.sh.
* It will create a new file containing changes for ruby.data in /tmp/installBuilder-ruby-data-$USER
* Diff /tmp/installBuilder-ruby-data-$USER with the rub.data file from Build-OMS-Agent-for-Linux/omsagent/installer/datafiles/.
* Observe only the new gem related records are added. Replace installer/datafiles/ruby.data with the content of installBuilder-ruby-data-$USER file

2. Building the new changes privately:
* Run ./configure the build environment with --enable-ulinux
* make
Install the private bundle and validate that /opt/microsoft/omsagent/ruby has the new gem changes.

In order to add a new Ruby gem into OMSAgent bundle when you do not have the new_gem_name.gem file on you local system you need to follow these steps:
1. Get the new_gem_name.gem file
* Install OMSAgent bundle on you local machine.
* Navigate to /opt/microsoft/omsagent/ruby and run gem install new_gem_name
* Clone Microsoft/Build-OMS-Agent-for-Linux github repo
* Find the newly installed new_gem_name.gem file from /opt/microsoft/omsagent/ruby path and copy it to Build-OMS-Agent-for-Linux//omsagent/source/ext/gems.
* Navigate to Build-OMS-Agent-for-Linux/omsagent/installer/scripts and update genRubyInstaller.sh with SOURCE_DIR to be /opt/microsoft/omsagent/ruby
* Run genRubyInstaller.sh. 
* It will create a new file containing changes for ruby.data in /tmp/installBuilder-ruby-data-$USER
* Diff /tmp/installBuilder-ruby-data-$USER with the rub.data file from Build-OMS-Agent-for-Linux/omsagent/installer/datafiles/.
* Observe only the new gem related records are added. Replace installer/datafiles/ruby.data with the content of installBuilder-ruby-data-$USER file
* Uninstall the agent (required to be able to build the agent from your private github depot)
* Put  modified commands to Build-OMS-Agent-for-Linux/omsagent/build/buildRuby.sh
(Example ${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/new_gem_name.gem)

2. Building the new changes privately:
* Navigate to Build-OMS-Agent-for-Linux/omsagent/build to configure the build environment with --enable-ulinux
* make
3. Observe that the ruby generated in intermediate folder contains the new gem and it's required files in

Note that if the new gem you are adding is dependent on other gems, you need to checkin dependent gems as well. 
As a reference you can look at how fluentd installs the dependant gems from vendor/cache
If your gem is depenendant on native libraries, the section "Dependencies to build a native package" in Build-OMS-Agent-for-Linux has to be updated accordingly.







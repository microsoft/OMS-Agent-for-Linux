## How to add a new gem to omsagent bundle installer

######To add a new Ruby gem into OMSAgent bundle if you have the .gem file on your local machine, you need to follow these steps:

Let us take mysql_2.0.gem  as an example. First, you will need to update the private build on your local machine with the new gem:
* Setup a private build system on your local machine. Configure the build with --enable-ulinux. And build the bundle.
* Copy mysql_2.0.gem into local build folder under /source/ext/gems.
* Navigate to /omsagent/build/ folder and put modified commands in buildRuby.sh
  Example, `${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/mysql_2.0.gem`
* Run `buildRuby.sh 100`
* Once the script is complete, it will build the new changes for ruby under /intermediate/\*/100/Ruby.
* Make sure you are in the build location. Then run `../installer/scripts/genRubyInstaller.sh`
  It will create the new ruby.data content in /tmp/installBuilder-ruby-data-$USER.
* Diff installBuilder-ruby-data-$USER with the ruby.data file from /installer/datafiles/
* Observe only mysql2 gem related records are added. 
* Replace /installer/datafiles/ruby.data with the content of installBuilder-ruby-data-$USER file
  
Now, perform another make to build the omsagent bundle with all the changes. 
Then , install the bundle and validate the ruby folder under /opt/microsoft/omsagent/ruby has all the new changes.
  
######To add a new Ruby gem into OMSAgent bundle if you DO NOT have the .gem file on you local machine, you need to follow these steps:

Let us take mysql2 as an example. First, you will need to get the mysql_2.0.gem , and update the private branch:
* Install OMS agent on your local machine.
* Navigate to /opt/microsoft/omsagent/ruby and run `./gem install mysql2`
* Observe the new gem is installed in /opt/microsoft/omsagent/ruby.
* Setup a private build system on your local machine to build the bundle with --enable-ulinux.
* Copy mysql_2.0.gem from /opt/microsoft/omsagent/ruby into the private build under /source/ext/gems folder.
* Navigate to /installer/scripts and update genRubyInstaller.sh with SOURCE_DIR to point to /opt/microsoft/omsagent/ruby.
* Run `genRubyInstaller.sh` 
It will create the new ruby.data content in /tmp/installBuilder-ruby-data-$USER.
* Diff installBuilder-ruby-data-$USER with the ruby.data file from /installer/datafiles/
* Observe only mysql2 gem related records are added. 
* Replace /installer/datafiles/ruby.data in build location with the content of installBuilder-ruby-data-$USER file
* Navigate to /omsagent/build/ folder and put modified commands in buildRuby.sh
  Example, `${RUBY_DESTDIR}/bin/gem install ${BASE_DIR}/source/ext/gems/mysql_2.0.gem`
* Uninstall omsagent to be able to build it privately.
* Navigate to build location. Run `./configure --enable-ulinux`. And build the bundle using make.
  
Then install the new bundle and validate the ruby folder under /opt/microsoft/omsagent/ruby has all the new changes.
  
Note that if your new .gem file adds dependencies on native packages that must be installed, update the [README.md](https://github.com/Microsoft/Build-OMS-Agent-for-Linux#Dependencies-to-build-a-native-package)
Note that if your new .gem is depending on other gems, the dependent gems need to be added to buildRuby.sh in non-dependent order. Always make sure you do not accidentally make the build download gems to satisfy dependencies.

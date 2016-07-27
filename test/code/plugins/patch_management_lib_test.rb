require 'test/unit'

require_relative '../../../source/code/plugins/patch_management_lib'
require_relative '../../../source/code/plugins/oms_common'
require_relative 'omstestlib'
require_relative 'oms_common_test'

class LinuxUpdatesTest < Test::Unit::TestCase

  @@delimiter = "_"

  def setup
    @installed_packages_xml_str = '<INSTANCE CLASSNAME="Inventory"><PROPERTY.ARRAY NAME="Instances" TYPE="string" EmbeddedObject="object"><VALUE.ARRAY><VALUE>&lt;INSTANCE CLASSNAME=&quot;MSFT_nxPackageResource&quot;&gt;&lt;PROPERTY NAME=&quot;Publisher&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Ubuntu Developers &amp;lt;ubuntu-devel-discuss@lists.ubuntu.com&amp;gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;ReturnCode&quot; TYPE=&quot;uint32&quot;&gt;&lt;VALUE&gt;0&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Name&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;autotools-dev&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;FilePath&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageGroup&quot; TYPE=&quot;boolean&quot;&gt;&lt;VALUE&gt;false&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Installed&quot; TYPE=&quot;boolean&quot;&gt;&lt;VALUE&gt;true&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;InstalledOn&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Unknown&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Version&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;20150820.1&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Ensure&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;present&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Architecture&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;all&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Arguments&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageManager&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageDescription&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Update infrastructure for config.{guess,sub} files&amp;#10; This package installs an up-to-date version of config.guess and&amp;#10; config.sub, used by the automake and libtool packages.  It provides&amp;#10; the canonical copy of those files for other packages as well.&amp;#10; .&amp;#10; It also documents in /usr/share/doc/autotools-dev/README.Debian.gz&amp;#10; best practices and guidelines for using autoconf, automake and&amp;#10; friends on Debian packages.  This is a must-read for any developers&amp;#10; packaging software that uses the GNU autotools, or GNU gettext.&amp;#10; .&amp;#10; Additionally this package provides seamless integration into Debhelper&amp;#10; or CDBS, allowing maintainers to easily update config.{guess,sub} files&amp;#10; in their packages.&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Size&quot; TYPE=&quot;uint32&quot;&gt;&lt;VALUE&gt;151&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;/INSTANCE&gt;</VALUE></VALUE.ARRAY></PROPERTY.ARRAY></INSTANCE>'

    @installed_packages_xml_str_with_installed_on_date = '<INSTANCE CLASSNAME="Inventory"><PROPERTY.ARRAY NAME="Instances" TYPE="string" EmbeddedObject="object"><VALUE.ARRAY><VALUE>&lt;INSTANCE CLASSNAME=&quot;MSFT_nxPackageResource&quot;&gt;&lt;PROPERTY NAME=&quot;Publisher&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Ubuntu Developers &amp;lt;ubuntu-devel-discuss@lists.ubuntu.com&amp;gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;ReturnCode&quot; TYPE=&quot;uint32&quot;&gt;&lt;VALUE&gt;0&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Name&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;autotools-dev&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;FilePath&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageGroup&quot; TYPE=&quot;boolean&quot;&gt;&lt;VALUE&gt;false&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Installed&quot; TYPE=&quot;boolean&quot;&gt;&lt;VALUE&gt;true&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;InstalledOn&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;1468202536&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Version&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;20150820.1&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Ensure&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;present&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Architecture&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;all&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Arguments&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageManager&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageDescription&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Update infrastructure for config.{guess,sub} files&amp;#10; This package installs an up-to-date version of config.guess and&amp;#10; config.sub, used by the automake and libtool packages.  It provides&amp;#10; the canonical copy of those files for other packages as well.&amp;#10; .&amp;#10; It also documents in /usr/share/doc/autotools-dev/README.Debian.gz&amp;#10; best practices and guidelines for using autoconf, automake and&amp;#10; friends on Debian packages.  This is a must-read for any developers&amp;#10; packaging software that uses the GNU autotools, or GNU gettext.&amp;#10; .&amp;#10; Additionally this package provides seamless integration into Debhelper&amp;#10; or CDBS, allowing maintainers to easily update config.{guess,sub} files&amp;#10; in their packages.&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Size&quot; TYPE=&quot;uint32&quot;&gt;&lt;VALUE&gt;151&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;/INSTANCE&gt;</VALUE></VALUE.ARRAY></PROPERTY.ARRAY></INSTANCE>'
    
    @installed_packages_xml_str_with_nil_installed_on_date = '<INSTANCE CLASSNAME="Inventory"><PROPERTY.ARRAY NAME="Instances" TYPE="string" EmbeddedObject="object"><VALUE.ARRAY><VALUE>&lt;INSTANCE CLASSNAME=&quot;MSFT_nxPackageResource&quot;&gt;&lt;PROPERTY NAME=&quot;Publisher&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Ubuntu Developers &amp;lt;ubuntu-devel-discuss@lists.ubuntu.com&amp;gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;ReturnCode&quot; TYPE=&quot;uint32&quot;&gt;&lt;VALUE&gt;0&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Name&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;autotools-dev&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;FilePath&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageGroup&quot; TYPE=&quot;boolean&quot;&gt;&lt;VALUE&gt;false&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Installed&quot; TYPE=&quot;boolean&quot;&gt;&lt;VALUE&gt;true&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;InstalledOn&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Version&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;20150820.1&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Ensure&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;present&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Architecture&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;all&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Arguments&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageManager&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;PackageDescription&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Update infrastructure for config.{guess,sub} files&amp;#10; This package installs an up-to-date version of config.guess and&amp;#10; config.sub, used by the automake and libtool packages.  It provides&amp;#10; the canonical copy of those files for other packages as well.&amp;#10; .&amp;#10; It also documents in /usr/share/doc/autotools-dev/README.Debian.gz&amp;#10; best practices and guidelines for using autoconf, automake and&amp;#10; friends on Debian packages.  This is a must-read for any developers&amp;#10; packaging software that uses the GNU autotools, or GNU gettext.&amp;#10; .&amp;#10; Additionally this package provides seamless integration into Debhelper&amp;#10; or CDBS, allowing maintainers to easily update config.{guess,sub} files&amp;#10; in their packages.&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Size&quot; TYPE=&quot;uint32&quot;&gt;&lt;VALUE&gt;151&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;/INSTANCE&gt;</VALUE></VALUE.ARRAY></PROPERTY.ARRAY></INSTANCE>'

    @available_updates_xml_str = '<INSTANCE CLASSNAME="Inventory"><PROPERTY.ARRAY NAME="Instances" TYPE="string" EmbeddedObject="object"><VALUE.ARRAY><VALUE>&lt;INSTANCE CLASSNAME=&quot;MSFT_nxAvailableUpdatesResource&quot;&gt;&lt;PROPERTY NAME=&quot;Name&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;dpkg&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Version&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;1.18.4ubuntu1.1&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Architecture&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;amd64&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Repository&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Ubuntu:15.04/xenial-updates&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;BuildDate&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;BuildDate&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;/INSTANCE&gt;</VALUE></VALUE.ARRAY></PROPERTY.ARRAY></INSTANCE>'

    @available_updates_xml_str_with_build_date = '<INSTANCE CLASSNAME="Inventory"><PROPERTY.ARRAY NAME="Instances" TYPE="string" EmbeddedObject="object"><VALUE.ARRAY><VALUE>&lt;INSTANCE CLASSNAME=&quot;MSFT_nxAvailableUpdatesResource&quot;&gt;&lt;PROPERTY NAME=&quot;Name&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;dpkg&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Version&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;1.18.4ubuntu1.1&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Architecture&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;amd64&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Repository&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Ubuntu:15.04/xenial-updates&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;BuildDate&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;1468202536&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;/INSTANCE&gt;</VALUE></VALUE.ARRAY></PROPERTY.ARRAY></INSTANCE>'

    @available_updates_xml_str_with_nil_build_date = '<INSTANCE CLASSNAME="Inventory"><PROPERTY.ARRAY NAME="Instances" TYPE="string" EmbeddedObject="object"><VALUE.ARRAY><VALUE>&lt;INSTANCE CLASSNAME=&quot;MSFT_nxAvailableUpdatesResource&quot;&gt;&lt;PROPERTY NAME=&quot;Name&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;dpkg&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Version&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;1.18.4ubuntu1.1&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Architecture&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;amd64&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Repository&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;Ubuntu:15.04/xenial-updates&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;BuildDate&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;/INSTANCE&gt;</VALUE></VALUE.ARRAY></PROPERTY.ARRAY></INSTANCE>'

    @inventoryPath = File.join(File.dirname(__FILE__), 'InventoryWithUpdates.xml')
    LinuxUpdates.prev_hash = nil
    LinuxUpdates.log = OMS::MockLog.new
  end

  def teardown

  end

  def test_strToXML
    xml = LinuxUpdates.strToXML(@installed_packages_xml_str)
    assert(xml.is_a?(REXML::Document), "Expected return type is REXML::Document")
  end

  def test_strToXML_fail
    assert_raise REXML::ParseException do
      LinuxUpdates.strToXML("<<<<")
    end
  end
  
  def test_getAvailableUpdatesInstancesXML
    xml = LinuxUpdates.strToXML(@available_updates_xml_str)
    assert(xml.root != nil, 'Failed find the root of the xml document')
    assert_equal("INSTANCE", xml.root.name)
    instances = LinuxUpdates.getInstancesXML(xml)
    
    assert_equal(1, instances.size)
    assert_equal("INSTANCE", instances[0].name)
    assert_equal("MSFT_nxAvailableUpdatesResource", instances[0].attributes['CLASSNAME'])
  end

  def test_availableUpdatesXMLtoHash
    instanceXMLstr = '{
      <INSTANCE CLASSNAME="MSFT_nxAvailableUpdatesResource">
        <PROPERTY NAME="Name" TYPE="string">
            <VALUE>dpkg</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Version" TYPE="string">
            <VALUE>1.18.4ubuntu1.1</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Architecture" TYPE="string">
            <VALUE>amd64</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Repository" TYPE="string">
            <VALUE>Ubuntu:16.04/xenial-updates</VALUE>
        </PROPERTY>
        <PROPERTY NAME="BuildDate" TYPE="string">
            <VALUE>BuildDate</VALUE>
        </PROPERTY>
      </INSTANCE>'
    
    expectedHash = {
      "CollectionName"=> "dpkg" + @@delimiter + "1.18.4ubuntu1.1" + @@delimiter + "Ubuntu_14.04",
      "Architecture"=>"amd64",
      "PackageName"=>"dpkg",
      "PackageVersion"=>"1.18.4ubuntu1.1",
      "Timestamp"=> nil,
      "Repository"=>"Ubuntu:16.04/xenial-updates",
      "Installed"=>false,
      "UpdateState"=>"Needed"
    }
    
    instanceXML = LinuxUpdates::strToXML(instanceXMLstr).root
    assert_equal("INSTANCE", instanceXML.name)
    assert_equal("MSFT_nxAvailableUpdatesResource", instanceXML.attributes['CLASSNAME'])
    instanceHash = LinuxUpdates::availableUpdatesXMLtoHash(instanceXML, "Ubuntu_14.04")
    assert_equal(expectedHash, instanceHash)
  end

  def test_getInstalledPackagesInstancesXML
    xml = LinuxUpdates.strToXML(@installed_packages_xml_str)
    assert(xml.root != nil, 'Failed find the root of the xml document')
    assert_equal("INSTANCE", xml.root.name)
    instances = LinuxUpdates.getInstancesXML(xml)
    
    assert_equal(1, instances.size)
    assert_equal("INSTANCE", instances[0].name)
    assert_equal("MSFT_nxPackageResource", instances[0].attributes['CLASSNAME'])
  end

  def test_installedUpdatesXMLtoHash
    instanceXMLstr = '
      <INSTANCE CLASSNAME="MSFT_nxPackageResource">
                <PROPERTY NAME="Publisher" TYPE="string">
                  <VALUE>Ubuntu Developers &amp;lt;ubuntu-devel-discuss@lists.ubuntu.com&amp;gt;</VALUE>
                </PROPERTY>
                <PROPERTY NAME="ReturnCode" TYPE="uint32">
                  <VALUE>0</VALUE>
                </PROPERTY>
                <PROPERTY NAME="Name" TYPE="string">
                  <VALUE>autotools-dev</VALUE>
                </PROPERTY>
                <PROPERTY NAME="FilePath" TYPE="string">
                  <VALUE />
                </PROPERTY>
                <PROPERTY NAME="PackageGroup" TYPE="boolean">
                  <VALUE>false</VALUE>
                </PROPERTY>
                <PROPERTY NAME="Installed" TYPE="boolean">
                  <VALUE>true</VALUE>
                </PROPERTY>
                <PROPERTY NAME="InstalledOn" TYPE="string">
                  <VALUE>Unknown</VALUE>
                </PROPERTY>
                <PROPERTY NAME="Version" TYPE="string">
                  <VALUE>20150820.1</VALUE>
                </PROPERTY>
                <PROPERTY NAME="Ensure" TYPE="string">
                  <VALUE>present</VALUE>
                </PROPERTY>
                <PROPERTY NAME="Architecture" TYPE="string">
                  <VALUE>all</VALUE>
                </PROPERTY>
                <PROPERTY NAME="Arguments" TYPE="string">
                  <VALUE />
                </PROPERTY>
                <PROPERTY NAME="PackageManager" TYPE="string">
                  <VALUE />
                </PROPERTY>
                <PROPERTY NAME="PackageDescription" TYPE="string">
                  <VALUE>Update infrastructure for config.{guess,sub} files
      This package installs an up-to-date version of config.guess and
      config.sub, used by the automake and libtool packages. It provides
      the canonical copy of those files for other packages as well.
      .
      It also documents in /usr/share/doc/autotools-dev/README.Debian.gz
      best practices and guidelines for using autoconf, automake and
      friends on Debian packages. This is a must-read for any developers
      packaging software that uses the GNU autotools, or GNU gettext.
      .
      Additionally this package provides seamless integration into Debhelper
      or CDBS, allowing maintainers to easily update config.{guess,sub} files
      in their packages.</VALUE>
                </PROPERTY>
                <PROPERTY NAME="Size" TYPE="uint32">
                  <VALUE>151</VALUE>
                </PROPERTY>
              </INSTANCE>'    

    expectedHash = {
      "CollectionName"=> "autotools-dev" + @@delimiter + "20150820.1" + @@delimiter + "Ubuntu_14.04",
      "Architecture"=>"all",
      "PackageName"=> "autotools-dev",
      "PackageVersion"=>"20150820.1",
      "Timestamp"=> nil,
      "Repository"=> nil,
      "Size"=>"151",
      "Installed"=>true,
      "UpdateState"=>"NotNeeded"
    }
    
    instanceXML = LinuxUpdates::strToXML(instanceXMLstr).root
    assert_equal("INSTANCE", instanceXML.name)
    assert_equal("MSFT_nxPackageResource", instanceXML.attributes['CLASSNAME'])
    instanceHash = LinuxUpdates::installedPackageXMLtoHash(instanceXML, "Ubuntu_14.04")
    assert_equal(expectedHash, instanceHash)
  end

  def test_installed_packages_transform_and_wrap
    expectedHash = {
            "DataType" => "LINUX_UPDATES_SNAPSHOT_BLOB",
            "IPName" => "Updates",
            "DataItems" => [{
                "Host" => "HostName",
                "AgentId" => "AgentId-123",
                "OSFullName" => "Ubuntu 16.04",
                "OSName" => "Ubuntu",
                "OSType" => "Linux",
                "OSVersion" => "16.04",
                "Timestamp" => "2016-03-15T19:02:38.577Z",
                "Collections" => [{
                    "CollectionName" => "autotools-dev_20150820.1_Ubuntu_16.04",
                    "Installed" => true,
                    "UpdateState"=>"NotNeeded",
                    "Architecture"=>"all",
                    "PackageName" => "autotools-dev",
                    "PackageVersion" => "20150820.1",
                    "Repository" => nil,
                    "Size" => "151",
                    "Timestamp" => nil
                }]
            }]
        }
    expectedTime = Time.utc(2016,3,15,19,2,38.5776)
    wrappedHash = LinuxUpdates::transform_and_wrap(@installed_packages_xml_str, "HostName", expectedTime, 
                                                   86400, "AgentId-123", "Ubuntu", "Ubuntu 16.04",
                                                   "16.04", "Ubuntu_16.04")
    assert_equal(expectedHash, wrappedHash)
  end
  
  def test_installed_packages_transform_and_wrap_with_installed_on_date
    expectedHash = {
            "DataType" => "LINUX_UPDATES_SNAPSHOT_BLOB",
            "IPName" => "Updates",
            "DataItems" => [{
                "Host" => "HostName",
                "AgentId" => "AgentId-123",
                "OSFullName" => "Ubuntu 16.04",
                "OSName" => "Ubuntu",
                "OSType" => "Linux",
                "OSVersion" => "16.04",
                "Timestamp" => "2016-03-15T19:02:38.577Z",
                "Collections" => [{
                    "CollectionName" => "autotools-dev_20150820.1_Ubuntu_16.04",
                    "Installed" => true,
                    "UpdateState"=>"NotNeeded",
                    "Architecture"=>"all",
                    "PackageName" => "autotools-dev",
                    "PackageVersion" => "20150820.1",
                    "Repository" => nil,
                    "Size" => "151",
                    "Timestamp" => "2016-07-11T02:02:16.000Z"
                }]
            }]
        }
    expectedTime = Time.utc(2016,3,15,19,2,38.5776)
    wrappedHash = LinuxUpdates::transform_and_wrap(@installed_packages_xml_str_with_installed_on_date, "HostName", expectedTime, 
                                                   86400, "AgentId-123", "Ubuntu", "Ubuntu 16.04",
                                                   "16.04", "Ubuntu_16.04")
    assert_equal(expectedHash, wrappedHash)
  end

  def test_installed_packages_transform_and_wrap_with_nil_installed_on_date
    expectedHash = {
            "DataType" => "LINUX_UPDATES_SNAPSHOT_BLOB",
            "IPName" => "Updates",
            "DataItems" => [{
                "Host" => "HostName",
                "AgentId" => "AgentId-123",
                "OSFullName" => "Ubuntu 16.04",
                "OSName" => "Ubuntu",
                "OSType" => "Linux",
                "OSVersion" => "16.04",
                "Timestamp" => "2016-03-15T19:02:38.577Z",
                "Collections" => [{
                    "CollectionName" => "autotools-dev_20150820.1_Ubuntu_16.04",
                    "Installed" => true,
                    "UpdateState"=>"NotNeeded",
                    "Architecture"=>"all",
                    "PackageName" => "autotools-dev",
                    "PackageVersion" => "20150820.1",
                    "Repository" => nil,
                    "Size" => "151",
                    "Timestamp" => nil
                }]
            }]
        }
    expectedTime = Time.utc(2016,3,15,19,2,38.5776)
    wrappedHash = LinuxUpdates::transform_and_wrap(@installed_packages_xml_str_with_nil_installed_on_date, "HostName", expectedTime, 
                                                   86400, "AgentId-123", "Ubuntu", "Ubuntu 16.04",
                                                   "16.04", "Ubuntu_16.04")
    assert_equal(expectedHash, wrappedHash)
  end
  
  def test_available_updates_transform_and_wrap
    expectedHash = {
            "DataType" => "LINUX_UPDATES_SNAPSHOT_BLOB",
            "IPName" => "Updates",
            "DataItems" => [{
                "Host" => "HostName",
                "AgentId" => "AgentId-123",
                "OSFullName" => "Ubuntu 15.04",
                "OSName" => "Ubuntu",
                "OSType" => "Linux",
                "OSVersion" => "15.04",
                "Timestamp" => "2016-03-15T19:02:38.577Z",
                "Collections" => [{
                    "CollectionName" => "dpkg_1.18.4ubuntu1.1_Ubuntu_14.04",
                    "Installed" => false,
                    "UpdateState"=>"Needed",
                    "Architecture"=>"amd64",
                    "PackageName" => "dpkg",
                    "PackageVersion" => "1.18.4ubuntu1.1",
                    "Repository" => "Ubuntu:15.04/xenial-updates",
                    "Timestamp" => nil
                }]
            }]
        }
    expectedTime = Time.utc(2016,3,15,19,2,38.5776)
    wrappedHash = LinuxUpdates::transform_and_wrap(@available_updates_xml_str, "HostName", expectedTime,
                                                   86400, "AgentId-123", "Ubuntu", "Ubuntu 15.04",
                                                   "15.04", "Ubuntu_15.04")
    assert_equal(expectedHash, wrappedHash)
  end

  def test_available_updates_transform_and_wrap_with_build_date
    expectedHash = {
            "DataType" => "LINUX_UPDATES_SNAPSHOT_BLOB",
            "IPName" => "Updates",
            "DataItems" => [{
                "Host" => "HostName",
                "AgentId" => "AgentId-123",
                "OSFullName" => "Ubuntu 15.04",
                "OSName" => "Ubuntu",
                "OSType" => "Linux",
                "OSVersion" => "15.04",
                "Timestamp" => "2016-03-15T19:02:38.577Z",
                "Collections" => [{
                    "CollectionName" => "dpkg_1.18.4ubuntu1.1_Ubuntu_14.04",
                    "Installed" => false,
                    "UpdateState"=>"Needed",
                    "Architecture"=>"amd64",
                    "PackageName" => "dpkg",
                    "PackageVersion" => "1.18.4ubuntu1.1",
                    "Repository" => "Ubuntu:15.04/xenial-updates",
                    "Timestamp" => "2016-07-11T02:02:16.000Z"
                }]
            }]
        }
    expectedTime = Time.utc(2016,3,15,19,2,38.5776)
    wrappedHash = LinuxUpdates::transform_and_wrap(@available_updates_xml_str_with_build_date, "HostName", expectedTime,
                                                   86400, "AgentId-123", "Ubuntu", "Ubuntu 15.04",
                                                   "15.04", "Ubuntu_15.04")
    assert_equal(expectedHash, wrappedHash)
  end

  def test_available_updates_transform_and_wrap_with_nil_build_date
    expectedHash = {
            "DataType" => "LINUX_UPDATES_SNAPSHOT_BLOB",
            "IPName" => "Updates",
            "DataItems" => [{
                "Host" => "HostName",
                "AgentId" => "AgentId-123",
                "OSFullName" => "Ubuntu 15.04",
                "OSName" => "Ubuntu",
                "OSType" => "Linux",
                "OSVersion" => "15.04",
                "Timestamp" => "2016-03-15T19:02:38.577Z",
                "Collections" => [{
                    "CollectionName" => "dpkg_1.18.4ubuntu1.1_Ubuntu_14.04",
                    "Installed" => false,
                    "UpdateState"=>"Needed",
                    "Architecture"=>"amd64",
                    "PackageName" => "dpkg",
                    "PackageVersion" => "1.18.4ubuntu1.1",
                    "Repository" => "Ubuntu:15.04/xenial-updates",
                    "Timestamp" => nil
                }]
            }]
        }
    expectedTime = Time.utc(2016,3,15,19,2,38.5776)
    wrappedHash = LinuxUpdates::transform_and_wrap(@available_updates_xml_str_with_nil_build_date, "HostName", expectedTime,
                                                   86400, "AgentId-123", "Ubuntu", "Ubuntu 15.04",
                                                   "15.04", "Ubuntu_15.04")
    assert_equal(expectedHash, wrappedHash)
  end
  
  def test_performance
    inventoryXMLstr = File.read(@inventoryPath)

    start = Time.now
    wrappedHash = LinuxUpdates::transform_and_wrap(inventoryXMLstr, "HostName", Time.now, 86400,
                                                   "AgentId-123", "Ubuntu", "Ubuntu 16.04", "16.04", 
                                                   "Ubuntu_16.04")
    finish = Time.now
    time_spent = finish - start
    # Test that duplicates are removed as well. The test data has 605 installedpackages and 20 available updates with some duplicates.
    assert_equal(618, wrappedHash["DataItems"][0]["Collections"].size, "Got the wrong number of instances (Combined - Installed and Available).")
    if time_spent > 5.0
      warn("Method transform_and_wrap too slow, it took #{time_spent.round(2)}s to complete. The current time set is 5s")
    end
  end
  
  # Test if it removes the duplicate installed package.
  def test_remove_duplicates_installed_packages
    inventoryXMLstr = File.read(@inventoryPath)
    inventoryXML = LinuxUpdates::strToXML(inventoryXMLstr)
    instancesXML = LinuxUpdates::getInstancesXML(inventoryXML)
    installedPackageXML = instancesXML.select { |instanceXML| LinuxUpdates::isInstalledPackageInstanceXML(instanceXML) }
    installedPackages = installedPackageXML.map { |installedPackage| LinuxUpdates::installedPackageXMLtoHash(installedPackage, "Ubuntu_16.04")}
    assert_equal(605, installedPackages.size)

    collectionNames = installedPackages.map { |installedPackage| installedPackage["CollectionName"] }
    collectionNamesSet = Set.new collectionNames
    assert_equal(598, collectionNamesSet.size) # 7 duplicates
    assert(collectionNamesSet.size < collectionNames.size, "Test data does not contain duplicate Collection Names")

    data_items_dedup = LinuxUpdates::removeDuplicateCollectionNames(installedPackages)
    assert_equal(collectionNamesSet.size, data_items_dedup.size, "Deduplication failed")
  end
  
  # Test if it removes the duplicate available package.
  def test_remove_duplicates_available_packages
    inventoryXMLstr = File.read(@inventoryPath)
    inventoryXML = LinuxUpdates::strToXML(inventoryXMLstr)
    instancesXML = LinuxUpdates::getInstancesXML(inventoryXML)
    availableUpdatesXML = instancesXML.select { |instanceXML| LinuxUpdates::isAvailableUpdateInstanceXML(instanceXML) }
    availableUpdates = availableUpdatesXML.map { |availableUpdate| LinuxUpdates::availableUpdatesXMLtoHash(availableUpdate, "Ubuntu_16.04")}
    assert_equal(25, availableUpdates.size)
    
    collectionNames = availableUpdates.map { |availableUpdate| availableUpdate["CollectionName"] }
    collectionNamesSet = Set.new collectionNames
    assert_equal(20, collectionNamesSet.size) # 5 duplicates
    assert(collectionNamesSet.size < collectionNames.size, "Test data does not contain duplicate Collection Names")

    data_items_dedup = LinuxUpdates::removeDuplicateCollectionNames(availableUpdates)
    assert_equal(collectionNamesSet.size, data_items_dedup.size, "Deduplication failed")
  end
end
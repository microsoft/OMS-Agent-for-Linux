require 'test/unit'
require_relative '../../../source/code/plugins/changetracking_lib'
require_relative 'omstestlib'
#include ChangeTracking

class ChangeTrackingTest < Test::Unit::TestCase

  def setup
    #Fluent::Test.setup
    @xml_str = '<INSTANCE CLASSNAME="Inventory"><PROPERTY.ARRAY NAME="Instances" TYPE="string" EmbeddedObject="object"><VALUE.ARRAY><VALUE>&lt;INSTANCE CLASSNAME=&quot;MSFT_nxServiceResource&quot;&gt;&lt;PROPERTY NAME=&quot;Name&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;-l:&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Runlevels&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;unknown option&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Enabled&quot; TYPE=&quot;boolean&quot;&gt;&lt;VALUE&gt;false&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;State&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;stopped&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Controller&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;init&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Path&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;PROPERTY NAME=&quot;Description&quot; TYPE=&quot;string&quot;&gt;&lt;VALUE&gt;&lt;/VALUE&gt;&lt;/PROPERTY&gt;&lt;/INSTANCE&gt;</VALUE></VALUE.ARRAY></PROPERTY.ARRAY></INSTANCE>'
    $log = OMS::MockLog.new
    @inventoryPath = File.join(File.dirname(__FILE__), 'Inventory.xml')
    ChangeTracking.prev_hash = nil
  end

  def teardown

  end

  def test_strToXML
    xml = ChangeTracking.strToXML(@xml_str)
    assert(xml.is_a?(REXML::Document), "Expected return type is REXML::Document")
  end


  def test_strToXML_fail
    assert_raise REXML::ParseException do
      ChangeTracking.strToXML("<<<<")
    end
  end

  def test_getInstancesXML
    xml = ChangeTracking.strToXML(@xml_str)
    assert(xml.root != nil, 'Failed find the root of the xml document')
    assert_equal("INSTANCE", xml.root.name)
    instances = ChangeTracking.getInstancesXML(xml)
    # puts ">>#{instances}<<"
    assert_equal(1, instances.size)
    assert_equal("INSTANCE", instances[0].name)
    assert_equal("MSFT_nxServiceResource", instances[0].attributes['CLASSNAME'])
  end

  def test_transform_xml_to_hash
    instanceXMLstr = %{
      <INSTANCE CLASSNAME="MSFT_nxServiceResource">
        <PROPERTY NAME="Name" TYPE="string">
          <VALUE>iprdump</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Runlevels" TYPE="string">
          <VALUE>2, 3, 4, 5</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Enabled" TYPE="boolean">
          <VALUE>false</VALUE>
        </PROPERTY>
        <PROPERTY NAME="State" TYPE="string">
          <VALUE>stopped</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Controller" TYPE="string">
          <VALUE>init</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Path" TYPE="string">
          <VALUE>/etc/rc.d/init.d/iprdump</VALUE>
        </PROPERTY>
        <PROPERTY NAME="Description" TYPE="string">
          <VALUE>IBM Power RAID adapter dump utility</VALUE>
        </PROPERTY>
      </INSTANCE>
    }
    expectedHash = {
      "CollectionName"=> "iprdump",
      "Name"=> "iprdump",
      "Description"=> "IBM Power RAID adapter dump utility",
      "State"=> "stopped",
      "Path"=> "/etc/rc.d/init.d/iprdump",
      "Runlevels"=> "2, 3, 4, 5",
      "Enabled"=> "false",
      "Controller"=> "init"
    }
    instanceXML = ChangeTracking::strToXML(instanceXMLstr).root
    assert_equal("INSTANCE", instanceXML.name)
    assert_equal("MSFT_nxServiceResource", instanceXML.attributes['CLASSNAME'])
    instanceHash = ChangeTracking::instanceXMLtoHash(instanceXML)
    assert_equal(expectedHash, instanceHash)
  end


  def test_transform_and_wrap
    expectedHash = {
                      "DataType"=>"CONFIG_CHANGE_BLOB",
                      "IPName"=>"changetracking",
                      "DataItems"=>[
                        {
                         "Timestamp"=>"2016-03-15T19:02:38.577Z",
                         "Computer"=>"HostName",
                         "ConfigChangeType"=>"Daemons",
                         "Collections"=>[
                          {
                           "Name"=>"-l:",
                           "CollectionName"=>"-l:",
                           "Description"=>"",
                           "State"=>"stopped",
                           "Path"=>"",
                           "Runlevels"=>"unknown option",
                           "Enabled"=>"false",
                           "Controller"=>"init"
                         }
                       ]
                     }
                   ]
                 }
    expectedTime = Time.utc(2016,3,15,19,2,38.5776)
    wrappedHash = ChangeTracking::transform_and_wrap(@xml_str, "HostName", expectedTime)
    assert_equal(expectedHash, wrappedHash)
  end

  def test_performance
    inventoryXMLstr = File.read(@inventoryPath)

    start = Time.now
    wrappedHash = ChangeTracking::transform_and_wrap(inventoryXMLstr, "HostName", Time.now)
    finish = Time.now
    time_spent = finish - start
    assert_equal(216, wrappedHash["DataItems"][0]["Collections"].size, "Expected 216 instances.")
    assert(time_spent < 0.5, "transform_and_wrap too slow, it took #{time_spent}s to complete.")
  end

  def test_force_send_true
    inventoryXMLstr = File.read(@inventoryPath)
    t = Time.now
    wrappedHash = ChangeTracking::transform_and_wrap(inventoryXMLstr, "HostName", t, true)
    wrappedHash2 = ChangeTracking::transform_and_wrap(inventoryXMLstr, "HostName", t, true)
    assert_equal(wrappedHash, wrappedHash2)
    assert_not_equal({}, wrappedHash2)
  end

  def test_force_send_false
    # If we don't 
    inventoryXMLstr = File.read(@inventoryPath)
    wrappedHash = ChangeTracking::transform_and_wrap(inventoryXMLstr, "HostName", Time.now, false)
    wrappedHash2 = ChangeTracking::transform_and_wrap(inventoryXMLstr, "HostName", Time.now, false)
    assert_not_equal({}, wrappedHash)
    assert_equal({}, wrappedHash2)
  end


  # def test_transform

  #   # Make sure that we read test onboarding information from the environment varibles
  #   assert(TEST_WORKSPACE_ID != nil, "TEST_WORKSPACE_ID should be set by the environment for this test to run.") 
  #   assert(TEST_SHARED_KEY.empty? == false, "TEST_SHARED_KEY should not be empty.")
  #   assert_equal(true, success, "Configuration should be loaded")
  #   assert_nothing_raised(RuntimeError, "Failed to send syslog data : '#{$log.logs}'") do
  #     output.handle_record("oms.syslog.local0.warn", record)
  #   end
  # end

end

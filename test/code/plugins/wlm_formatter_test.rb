require 'test/unit'
require_relative '../../../source/code/plugins/wlm_formatter'
require_relative 'omstestlib'

class In_WLM_Formatter_test < Test::Unit::TestCase

  def setup
    $log = OMS::MockLog.new
    wlm_class_file = "#{ENV['BASE_DIR']}/installer/conf/universal.linux.json"
    WLM::MPStore.Initialize
    WLM::MPStore.load(wlm_class_file)
  end # method setup

  def teardown
  end

  def test_wlm_system_class_instance
    class_inst = WLM::WLMClassInstance.new("Universal Linux Computer")
    class_inst.add_cim_property("CSName", "TestCSName")
    class_inst.add_cim_property("CurrentTimeZone", "1234")

    assert_equal(class_inst.get_class_id, "30bc9ca4-f724-93f4-2208-58e872489b95", "Unexpected class ID")

    expected_key_props = {"5442c0f1-3251-3bf6-6f1b-d8c6f333afc3" => "TestCSName".to_sym}
    assert_equal(class_inst.get_key_properties, expected_key_props, "Unexpected key properties")

    expected_props = {
                       "5442c0f1-3251-3bf6-6f1b-d8c6f333afc3" => "TestCSName".to_sym, 
                       "883cd2bb-eb57-b4ff-bbf2-69b7cf4570dc" => "TestCSName".to_sym, 
                       "904bd983-8e8a-1ae4-5a2c-94b34fda675c" => "1234".to_sym
                     }
    assert_equal(class_inst.get_all_properties, expected_props, "Unexpected properties")
  end # method test_wlm_class_instance
  
  def test_wlm_logical_disk_class_instance
    class_inst = WLM::WLMClassInstance.new("Logical Disk")
    class_inst.add_key_property("5442c0f1-3251-3bf6-6f1b-d8c6f333afc3","TestCSName")
    class_inst.add_cim_property("Name","LDisk")
    class_inst.add_cim_property("FileSystemType","FSType")
    class_inst.add_cim_property("CompressionMethod","CMethod")
    class_inst.add_cim_property("FileSystemSize","FSSize")
    
    expected_key_props = {
                           "5442c0f1-3251-3bf6-6f1b-d8c6f333afc3" => "TestCSName".to_sym,
                           "47ea2d8d-a28f-161b-14e1-5cc98b736208" => "LDisk".to_sym
                         }
    assert_equal(class_inst.get_key_properties, expected_key_props, "Unexpected key properties")
    
    expected_props = {
                       "5442c0f1-3251-3bf6-6f1b-d8c6f333afc3" => "TestCSName".to_sym, 
                       "47ea2d8d-a28f-161b-14e1-5cc98b736208" => "LDisk".to_sym, 
                       "883cd2bb-eb57-b4ff-bbf2-69b7cf4570dc" => "LDisk".to_sym,
                       "03414ef5-5e89-39cc-c858-7a6751b10fdc" => "LDisk".to_sym,
                       "8714ce8a-1d61-b2b4-ffb6-1ffb73cc4fbc" => "FSType".to_sym,
                       "3111f912-5791-3853-1464-d3f4a0b0243e" => "CMethod".to_sym,
                       "da334500-da1c-476a-69d6-732001aade17" => "FSSize".to_sym
                     }
    assert_equal(class_inst.get_all_properties, expected_props, "Unexpected properties")
  end # method test_wlm_logical_disk_class_instance

end # In_WLM_Formatter_test

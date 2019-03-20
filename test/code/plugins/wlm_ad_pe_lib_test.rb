require 'test/unit'
require_relative '../../../source/code/plugins/wlm_ad_pe_lib'
require_relative 'omstestlib'

class WlmAutoDiscoverySourceTest < Test::Unit::TestCase
  
  class MockCommandHelper < WLM::CommandHelper
    
    attr_reader :command_name
    def initialize
      command_name = "testcommand"
      super(command_name, command_name)
    end
  
    def execute_command(params)
      @executed = true 
      @is_success = true
    end

    def is_success?
      return true
    end

  end #class

  class MockFailedCommandHelper < WLM::CommandHelper
    def initialize
      @command_name = "failcommand"
    end 

    def execute_command(params)
      @executed = true
      @is_success = true
    end

    def is_success?
      return false
    end
  end

  class MockCommon 
    def get_hostname
      return "MockHostName"
    end
  end #class

  def setup 
    @common = MockCommon.new
  end #def

  def test_process_enumeration
    time = "2018-04-13T09:45:39.897Z"

    config = [{
      "ServiceName" => "DummyService",
       "PossibleDaemons" => ["dummy","dummy2"]
    }]
    expected_result = {"DataItems"=> [{
       "EncodedVMMetadata"=>"eyJDb21tYW5kTmFtZSI6InRlc3Rjb21tYW5kIiwiRHVtbXlTZXJ2aWNlIjoiMSIsIlRpbWVTdGFtcCI6IjIwMTgtMDQtMTNUMDk6NDU6MzkuODk3WiIsIkhvc3QiOiJNb2NrSG9zdE5hbWUiLCJPU1R5cGUiOiJMaW51eCIsIkF1dG9EaXNjb3ZlcnkiOiIxIn0="}],
       "DataType"=>"WLM_DATA_TYPE",
       "IPName"=>"WLM_IP"}

    commands = [MockCommandHelper.new]

    wlm_pe = WLM::WlmProcessEnumeration.new(config, @common, commands)
    result = wlm_pe.get_data(time, "WLM_DATA_TYPE", "WLM_IP")
    assert_equal(expected_result, result)
  end

  def test_failing_command_process_enumeration
    time = "2018-04-13T09:45:39.897Z"
    #time = Time.parse("2014-12-04")

    config = [{
      "ServiceName" => "DummyService",
       "PossibleDaemons" => ["dummy","dummy2"]
    }]

    commands = [MockFailedCommandHelper.new]

    wlm_pe = WLM::WlmProcessEnumeration.new(config, @common, commands)

    result = wlm_pe.get_data(time.to_s, "WLM_DATA_TYPE", "WLM_IP")
    
    #if none of the services where found by all the commands listed. There should be no data out of the get_data method.
    expected_result = {"DataItems"=>[{
       "EncodedVMMetadata"=>"eyJUaW1lU3RhbXAiOiIyMDE4LTA0LTEzVDA5OjQ1OjM5Ljg5N1oiLCJIb3N0IjoiTW9ja0hvc3ROYW1lIiwiT1NUeXBlIjoiTGludXgiLCJBdXRvRGlzY292ZXJ5IjoiMSJ9"}],
       "DataType"=>"WLM_DATA_TYPE",
       "IPName"=>"WLM_IP"}
    assert_equal(expected_result, result)

  end

  def test_command_helper
    command = WLM::CommandHelper.new("ps -ef | grep %s", "testcommand")
    command.execute_command("random_service_name")
    assert_equal(true, command.is_success?)    
  end

  def teardown
    #Garbage collector
  end
  

end #class

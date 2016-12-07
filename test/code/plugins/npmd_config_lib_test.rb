#!/usr/bin/ruby -w

require 'test/unit'
require_relative '../../../source/code/plugins/npmd_config_lib'

class Logger
    def self.logToStdOut(msg, depth=0)
        #puts msg
    end
    class << self
        alias_method :logError, :logToStdOut
        alias_method :logInfo,  :logToStdOut
        alias_method :logWarn,  :logToStdOut
    end
end


class NPMDConfigUT < Test::Unit::TestCase

    def setup
        @test_desc01 = "Test Case 01: Valid UI XML Configuration"
        @test_desc02 = "Test Case 02: Invalid configuration version"
        @test_desc03 = "Test Case 03: Mismatched XML tags"
        @test_desc04 = "Test Case 04: Invalid configuration tags"
        @test_desc05 = "Test Case 05: Invalid json between tags"
        @test_desc06 = "Test Case 06: Missing agent capabilities"
        @test_desc07 = "Test Case 07: Missing rule protocol"
        @test_desc08 = "Test Case 08: Undefined subnet ids in config"
        @test_desc09 = "Test Case 09: IPV6 config gets compressed ips"

        @test_input_ui_config01 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'
        @test_input_ui_config02 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="2"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'
        @test_input_ui_config03 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'
        @test_input_ui_config04 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfiguration><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfiguration></Configuration>'
        @test_input_ui_config05 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]} "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'
        @test_input_ui_config06 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}]}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'
        @test_input_ui_config07 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[]}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'
        @test_input_ui_config08 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3","4"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'
        @test_input_ui_config09 = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3","4"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21","4":"2404:f801:4800:14::/64"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"},"3":{"IPs":[{"Value":"2404:f801:4800:14:215:5dff:feb0:4706","Subnet":"4"}],"Protocol":"2"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'

        @hash_output_ui_config01={"Networks"=>[{"Name"=>"Default", "Subnets"=>["1", "2"]},{"Name"=>"NewOne", "Subnets"=>["3"]}],"Subnets"=>{"1"=>"65.171.0.0/16", "2"=>"198.165.0.0/21", "3"=>"162.128.0.0/21"},"Agents"=>[{"Guid"=>"1","Capability"=>"1","IPs"=>[{"IP"=>"65.171.126.72", "SubnetName"=>"1"},{"IP"=>"65.171.126.73", "SubnetName"=>"1"}]},{"Guid"=>"2","Capability"=>"1","IPs"=>[{"IP"=>"65.271.126.72", "SubnetName"=>"2"}]}],"Rules"=>[{"Name"=>"Default","LossThreshold"=>-1.0,"LatencyThreshold"=>-1.0,"Protocol"=>1,"Rules"=>[{"SN"=>"*", "SS"=>"*", "DN"=>"*", "DS"=>"*"}],"Exceptions"=>[]}]}
        @hash_output_ui_config02=nil
        @hash_output_ui_config03=nil
        @hash_output_ui_config04=nil
        @hash_output_ui_config05=nil
        @hash_output_ui_config06={"Networks"=>[{"Name"=>"Default", "Subnets"=>["1", "2"]}, {"Name"=>"NewOne", "Subnets"=>["3"]}], "Subnets"=>{"1"=>"65.171.0.0/16", "2"=>"198.165.0.0/21", "3"=>"162.128.0.0/21"}, "Agents"=>[{"Guid"=>"1", "IPs"=>[{"IP"=>"65.171.126.72", "SubnetName"=>"1"}, {"IP"=>"65.171.126.73", "SubnetName"=>"1"}]}, {"Guid"=>"2", "Capability"=>"1", "IPs"=>[{"IP"=>"65.271.126.72", "SubnetName"=>"2"}]}], "Rules"=>[{"Name"=>"Default", "LossThreshold"=>-1.0, "LatencyThreshold"=>-1.0, "Protocol"=>1, "Rules"=>[{"SN"=>"*", "SS"=>"*", "DN"=>"*", "DS"=>"*"}], "Exceptions"=>[]}]}
        @hash_output_ui_config07={"Networks"=>[{"Name"=>"Default", "Subnets"=>["1", "2"]}, {"Name"=>"NewOne", "Subnets"=>["3"]}], "Subnets"=>{"1"=>"65.171.0.0/16", "2"=>"198.165.0.0/21", "3"=>"162.128.0.0/21"}, "Agents"=>[{"Guid"=>"1", "Capability"=>"1", "IPs"=>[{"IP"=>"65.171.126.72", "SubnetName"=>"1"}, {"IP"=>"65.171.126.73", "SubnetName"=>"1"}]}, {"Guid"=>"2", "Capability"=>"1", "IPs"=>[{"IP"=>"65.271.126.72", "SubnetName"=>"2"}]}], "Rules"=>[{"Name"=>"Default", "LossThreshold"=>-1.0, "LatencyThreshold"=>-1.0, "Rules"=>[{"SN"=>"*", "SS"=>"*", "DN"=>"*", "DS"=>"*"}], "Exceptions"=>[]}]}
        @hash_output_ui_config08={"Networks"=>[{"Name"=>"Default", "Subnets"=>["1", "2"]}, {"Name"=>"NewOne", "Subnets"=>["3", "4"]}], "Subnets"=>{"1"=>"65.171.0.0/16", "2"=>"198.165.0.0/21", "3"=>"162.128.0.0/21"}, "Agents"=>[{"Guid"=>"1", "Capability"=>"1", "IPs"=>[{"IP"=>"65.171.126.72", "SubnetName"=>"1"}, {"IP"=>"65.171.126.73", "SubnetName"=>"1"}]}, {"Guid"=>"2", "Capability"=>"1", "IPs"=>[{"IP"=>"65.271.126.72", "SubnetName"=>"2"}]}], "Rules"=>[{"Name"=>"Default", "LossThreshold"=>-1.0, "LatencyThreshold"=>-1.0, "Protocol"=>1, "Rules"=>[{"SN"=>"*", "SS"=>"*", "DN"=>"*", "DS"=>"*"}], "Exceptions"=>[]}]}
        @hash_output_ui_config09={"Networks"=>[{"Name"=>"Default", "Subnets"=>["1", "2"]}, {"Name"=>"NewOne", "Subnets"=>["3", "4"]}], "Subnets"=>{"1"=>"65.171.0.0/16", "2"=>"198.165.0.0/21", "3"=>"162.128.0.0/21", "4"=>"2404:f801:4800:14::/64"}, "Agents"=>[{"Guid"=>"1", "Capability"=>"1", "IPs"=>[{"IP"=>"65.171.126.72", "SubnetName"=>"1"}, {"IP"=>"65.171.126.73", "SubnetName"=>"1"}]}, {"Guid"=>"2", "Capability"=>"1", "IPs"=>[{"IP"=>"65.271.126.72", "SubnetName"=>"2"}]}, {"Guid"=>"3", "Capability"=>"2", "IPs"=>[{"IP"=>"2404:f801:4800:14:215:5dff:feb0:4706", "SubnetName"=>"4"}]}], "Rules"=>[{"Name"=>"Default", "LossThreshold"=>-1.0, "LatencyThreshold"=>-1.0, "Protocol"=>1, "Rules"=>[{"SN"=>"*", "SS"=>"*", "DN"=>"*", "DS"=>"*"}], "Exceptions"=>[]}]}

        @string_agent_config01='<Configuration><Agents><Agent Name="1" Capabilities="1"><IPConfiguration IP="65.171.126.72" Mask="255.255.0.0"/><IPConfiguration IP="65.171.126.73" Mask="255.255.0.0"/></Agent><Agent Name="2" Capabilities="1"><IPConfiguration IP="65.271.126.72" Mask="255.255.248.0"/></Agent></Agents><Networks><Network Name="Default"><Subnet ID="65.171.0.0" Disabled="False" Tag=""/><Subnet ID="198.165.0.0" Disabled="False" Tag=""/></Network><Network Name="NewOne"><Subnet ID="162.128.0.0" Disabled="False" Tag=""/></Network></Networks><Rules><Rule Name="Default" Description="" Protocol="1"><AlertConfiguration><Loss Threshold="-1.0"/><Latency Threshold="-1.0"/></AlertConfiguration><NetworkTestMatrix><SubnetPair SourceSubnet="*" SourceNetwork="*" DestSubnet="*" DestNetwork="*"/></NetworkTestMatrix></Rule></Rules></Configuration>'.gsub(/\s+/,"")
        @string_agent_config02=nil
        @string_agent_config03=nil
        @string_agent_config04=nil
        @string_agent_config05=nil
        @string_agent_config06='<Configuration><Agents><AgentName="1"><IPConfigurationIP="65.171.126.72"Mask="255.255.0.0"/><IPConfigurationIP="65.171.126.73"Mask="255.255.0.0"/></Agent><AgentName="2"Capabilities="1"><IPConfigurationIP="65.271.126.72"Mask="255.255.248.0"/></Agent></Agents><Networks><NetworkName="Default"><SubnetID="65.171.0.0"Disabled="False"Tag=""/><SubnetID="198.165.0.0"Disabled="False"Tag=""/></Network><NetworkName="NewOne"><SubnetID="162.128.0.0"Disabled="False"Tag=""/></Network></Networks><Rules><RuleName="Default"Description=""Protocol="1"><AlertConfiguration><LossThreshold="-1.0"/><LatencyThreshold="-1.0"/></AlertConfiguration><NetworkTestMatrix><SubnetPairSourceSubnet="*"SourceNetwork="*"DestSubnet="*"DestNetwork="*"/></NetworkTestMatrix></Rule></Rules></Configuration>'.gsub(/\s+/,"")
        @string_agent_config07='<Configuration><Agents><AgentName="1"Capabilities="1"><IPConfigurationIP="65.171.126.72"Mask="255.255.0.0"/><IPConfigurationIP="65.171.126.73"Mask="255.255.0.0"/></Agent><AgentName="2"Capabilities="1"><IPConfigurationIP="65.271.126.72"Mask="255.255.248.0"/></Agent></Agents><Networks><NetworkName="Default"><SubnetID="65.171.0.0"Disabled="False"Tag=""/><SubnetID="198.165.0.0"Disabled="False"Tag=""/></Network><NetworkName="NewOne"><SubnetID="162.128.0.0"Disabled="False"Tag=""/></Network></Networks><Rules><RuleName="Default"Description=""><AlertConfiguration><LossThreshold="-1.0"/><LatencyThreshold="-1.0"/></AlertConfiguration><NetworkTestMatrix><SubnetPairSourceSubnet="*"SourceNetwork="*"DestSubnet="*"DestNetwork="*"/></NetworkTestMatrix></Rule></Rules></Configuration>'.gsub(/\s+/,"")
        @string_agent_config08='<Configuration><Agents><AgentName="1"Capabilities="1"><IPConfigurationIP="65.171.126.72"Mask="255.255.0.0"/><IPConfigurationIP="65.171.126.73"Mask="255.255.0.0"/></Agent><AgentName="2"Capabilities="1"><IPConfigurationIP="65.271.126.72"Mask="255.255.248.0"/></Agent></Agents><Networks><NetworkName="Default"><SubnetID="65.171.0.0"Disabled="False"Tag=""/><SubnetID="198.165.0.0"Disabled="False"Tag=""/></Network><NetworkName="NewOne"><SubnetID="162.128.0.0"Disabled="False"Tag=""/></Network></Networks><Rules><RuleName="Default"Description=""Protocol="1"><AlertConfiguration><LossThreshold="-1.0"/><LatencyThreshold="-1.0"/></AlertConfiguration><NetworkTestMatrix><SubnetPairSourceSubnet="*"SourceNetwork="*"DestSubnet="*"DestNetwork="*"/></NetworkTestMatrix></Rule></Rules></Configuration>'.gsub(/\s+/,"")
        @string_agent_config09='<Configuration><Agents><AgentName="1"Capabilities="1"><IPConfigurationIP="65.171.126.72"Mask="255.255.0.0"/><IPConfigurationIP="65.171.126.73"Mask="255.255.0.0"/></Agent><AgentName="2"Capabilities="1"><IPConfigurationIP="65.271.126.72"Mask="255.255.248.0"/></Agent><AgentName="3"Capabilities="2"><IPConfigurationIP="2404:f801:4800:14:215:5dff:feb0:4706"Mask="ffff:ffff:ffff:ffff::"/></Agent></Agents><Networks><NetworkName="Default"><SubnetID="65.171.0.0"Disabled="False"Tag=""/><SubnetID="198.165.0.0"Disabled="False"Tag=""/></Network><NetworkName="NewOne"><SubnetID="162.128.0.0"Disabled="False" Tag=""/><SubnetID="2404:f801:4800:14::"Disabled="False"Tag=""/></Network></Networks><Rules><RuleName="Default" Description=""Protocol="1"><AlertConfiguration><LossThreshold="-1.0"/><LatencyThreshold="-1.0"/></AlertConfiguration><NetworkTestMatrix><SubnetPairSourceSubnet="*"SourceNetwork="*"DestSubnet="*"DestNetwork="*"/></NetworkTestMatrix></Rule></Rules></Configuration>'.gsub(/\s+/,"")
    end

    def validate_test_case(test_desc, ui_config, ui_output_hash, agent_config_str)
        _intHash = nil
        begin
            _intHash = NPMDConfig::UIConfigParser.parse(ui_config)
        rescue Exception => e
            # Ignore exception as some are meant for failing
        end
        unless ui_output_hash.nil?
            assert_equal(ui_output_hash, _intHash, "#{test_desc}: Failed while getting uiconfig hash")
        else
            assert(_intHash.nil?, "#{test_desc}: Failed as expectation is to get nil after UI config parsing")
        end

        unless _intHash.nil?
            _xmlConfig = nil
            begin
                _xmlConfig = NPMDConfig::AgentConfigCreator.createXmlFromUIConfigHash(_intHash)
            rescue Exception => e
                # Ignore exception as some are meant for failing
            end
            if agent_config_str.nil?
                assert(_xmlConfig.nil?, "#{test_desc}: Failed as expectation is to get nil after agent config generation")
            elsif _xmlConfig.nil?
                assert(false, "#{test_desc}: Failed as expected agent config xml was not nil")
            else
                _xmlConfig.gsub!(/\s+/, "")
                _xmlConfig.gsub!("\n","")
                _xmlConfig.gsub!(/\'/,"\"")
                assert_equal(agent_config_str, _xmlConfig, "#{test_desc}: Failed agent config xml mismatch")
            end
        end
    end

    def test_case_01
        validate_test_case(@test_desc01, @test_input_ui_config01, @hash_output_ui_config01, @string_agent_config01)
    end

    def test_case_02
        validate_test_case(@test_desc02, @test_input_ui_config02, @hash_output_ui_config02, @string_agent_config02)
    end

    def test_case_03
        validate_test_case(@test_desc03, @test_input_ui_config03, @hash_output_ui_config03, @string_agent_config03)
    end

    def test_case_04
        validate_test_case(@test_desc04, @test_input_ui_config04, @hash_output_ui_config04, @string_agent_config04)
    end

    def test_case_05
        validate_test_case(@test_desc05, @test_input_ui_config05, @hash_output_ui_config05, @string_agent_config05)
    end

    def test_case_06
        validate_test_case(@test_desc06, @test_input_ui_config06, @hash_output_ui_config06, @string_agent_config06)
    end

    def test_case_07
        validate_test_case(@test_desc07, @test_input_ui_config07, @hash_output_ui_config07, @string_agent_config07)
    end

    def test_case_08
        validate_test_case(@test_desc08, @test_input_ui_config08, @hash_output_ui_config08, @string_agent_config08)
    end

    def test_case_09
        validate_test_case(@test_desc09, @test_input_ui_config09, @hash_output_ui_config09, @string_agent_config09)
    end
end

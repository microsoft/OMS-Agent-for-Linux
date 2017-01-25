class Logger

    require 'thread'

    LOG_DEPTH_INC_RESC = 1 # Depth increase of method scope for rescue
    LOG_DEPTH_INC_LOOP = 2 # Depth increase of method scope for loop

    def self.log_error(msg, depth=0)
        _methodname = getMethodname(depth)
        _message = "[#{_methodname}]:#{msg}"
        $log.error "[NPMD]:#{_message}"
    end
    def self.log_info(msg, depth=0)
        _methodname = getMethodname(depth)
        $log.info "[NPMD]:[#{_methodname}]:#{msg}"
    end
    def self.log_warn(msg, depth=0)
        _methodname = getMethodname(depth)
        $log.warn "[NPMD]:[#{_methodname}]:#{msg}"
    end

    class << self
        alias_method :logError, :log_error
        alias_method :logInfo,  :log_info
        alias_method :logWarn,  :log_warn
    end

    private

    def self.getMethodname(depth)
        _depth = depth > 0 ? depth : 0
        begin
            caller_locations(2 + _depth, 1)[0].label
        rescue
            caller_locations(2 + LOG_DEPTH_INC_RESC, 1)[0].label
        end
    end

    def self.loop
        LOG_DEPTH_INC_LOOP
    end

    def self.resc
        LOG_DEPTH_INC_RESC
    end
end

# Module to parse config received from DSC and generate Agent Configuration
module NPMDConfig

    require 'rexml/document'
    require 'json'
    require 'ipaddr'

    # Need to have method to get the subnetmask
    class ::IPAddr
        def getNetMaskString
            _to_string(@mask_addr)
        end
    end

    # This class holds the methods for creating
    # a config understood by NPMD Agent from a hash
    class AgentConfigCreator
        public

        # Variables for tracking errors
        @@agent_ip_drops = 0
        @@agent_drops = 0
        @@network_subnet_drops = 0
        @@network_drops = 0
        @@rule_subnetpair_drops = 0
        @@rule_drops = 0

        # Strings utilized in drop summary
        DROP_IPS        = "Agent IPs"
        DROP_AGENTS     = "Agents"
        DROP_SUBNETS    = "Network subnets"
        DROP_NETWORKS   = "Networks"
        DROP_SUBNETPAIRS= "Rule subnetpairs"
        DROP_RULES      = "Rules"

        # Reset error checking
        def self.resetErrorCheck
            @@agent_ip_drops = 0
            @@agent_drops = 0
            @@network_subnet_drops = 0
            @@network_drops = 0
            @@rule_subnetpair_drops = 0
            @@rule_drops = 0
        end

        # Generating the error string
        def self.getErrorSummary
            _agentIpDrops=""
            _agentDrops=""
            _networkSNDrops=""
            _networkDrops=""
            _ruleSNPairDrops=""
            _ruleDrops=""

            if @@agent_ip_drops != 0
                _agentIpDrops = "#{DROP_IPS}=#{@@agent_ip_drops}"
            end
            if @@agent_drops != 0
                _agentDrops= "#{DROP_AGENTS}=#{@@agent_drops}"
            end
            if @@network_subnet_drops != 0
                _networkSNDrops = "#{DROP_SUBNETS}=#{@@network_subnet_drops}"
            end
            if @@network_drops != 0
                _networkDrops = "#{DROP_NETWORKS}=#{@@network_drops}"
            end
            if @@rule_subnetpair_drops != 0
                _ruleSNPairDrops = "#{DROP_SUBNETPAIRS}=#{@@rule_subnetpair_drops}"
            end
            if @@rule_drops != 0
                _ruleDrops = "#{DROP_RULES}=#{@@rule_drops}"
            end
            _str =  _agentIpDrops + " " + _agentDrops + " " +
                    _networkSNDrops + " " + _networkDrops + " " +
                    _ruleSNPairDrops + " " + _ruleDrops
        end

        # Only accessible method
        def self.createXmlFromUIConfigHash(configHash)
            begin
                _subnetInfo = getProcessedSubnetHash(configHash["Subnets"])
                _doc = REXML::Document.new
                _doc.add_element("Configuration")
                _agentsElement = createAgentElements(configHash["Agents"], _subnetInfo["Masks"])
                _doc.root.elements << _agentsElement
                _networksElement = createNetworkElements(configHash["Networks"], _subnetInfo["IDs"])
                _doc.root.elements << _networksElement
                _rulesElement = createRuleElements(configHash["Rules"], _subnetInfo["IDs"])
                _doc.root.elements << _rulesElement

                _formatter = REXML::Formatters::Pretty.new(2)
                _formatter.compact = true

                _xml = String.new
                _formatter.write(_doc, _xml)

                _xml
            rescue StandardError => e
                Logger::logError "Got error creating XML from UI Hash: #{e}", Logger::resc
                raise "Got error creating AgentXml: #{e}"
            end
        end

        private

        def self.getNetMask(ipaddrObj)
            _tempIp = IPAddr.new(ipaddrObj.getNetMaskString)
            _tempIp.to_s
        end

        def self.getProcessedSubnetHash(subnetHash)
            _h = Hash.new
            _h["Masks"] = Hash.new
            _h["IDs"] = Hash.new
            begin
                subnetHash.each do |key, value|
                    _tempIp = IPAddr.new(value)
                    _h["Masks"][key] = getNetMask(_tempIp)
                    _h["IDs"][key] = _tempIp.to_s
                end
                _h
            rescue StandardError => e
                Logger::logError "Got error while creating subnet hash: #{e}", Logger::resc
                nil
            end
        end

        def self.createAgentElements(agentArray, maskHash)
            _agents = REXML::Element.new("Agents")
            agentArray.each do |x|
                _agent = REXML::Element.new("Agent")
                _agent.add_attribute("Name", x["Guid"])
                _agent.add_attribute("Capabilities", x["Capability"])
                x["IPs"].each do |ip|
                    _ipConfig = REXML::Element.new("IPConfiguration")
                    _ipConfig.add_attribute("IP", ip["IP"])
                    _subnetMask = maskHash[ip["SubnetName"]]
                    if _subnetMask.nil?
                        Logger::logWarn "Did not find subnet mask for subnet name #{ip["SubnetName"]} in hash", 2*Logger::loop
                        @@agent_ip_drops += 1
                    else
                        _ipConfig.add_attribute("Mask", maskHash[ip["SubnetName"]])
                        _agent.elements << _ipConfig
                    end
                end
                if _agent.elements.empty?
                    @@agent_drops += 1
                else
                    _agents.elements << _agent
                end
            end
            _agents
        end

        def self.createNetworkElements(networkArray, subnetIdHash)
            _networks = REXML::Element.new("Networks")
            networkArray.each do |x|
                _network = REXML::Element.new("Network")
                _network.add_attribute("Name", x["Name"])
                x["Subnets"].each do |sn|
                    _subnetId = subnetIdHash[sn]
                    if _subnetId.nil?
                        Logger::logWarn "Did not find subnet id for subnet name #{sn} in hash", 2*Logger::loop
                        @@network_subnet_drops += 1
                    else
                        _snConfig = REXML::Element.new("Subnet")
                        _snConfig.add_attribute("ID", subnetIdHash[sn])
                        _snConfig.add_attribute("Disabled", "False")
                        _snConfig.add_attribute("Tag", "")
                        _network.elements << _snConfig
                    end
                end
                if _network.elements.empty?
                    @@network_drops += 1
                else
                    _networks.elements << _network
                end
            end
            _networks
        end

        def self.createActOnElements(actOnArray, subnetIdHash, xmlElemName)
            _xmlElement = REXML::Element.new(xmlElemName)
            actOnArray.each do |a|
                _sSubnetId = "*"
                _dSubnetId = "*"
                if a["SS"] != "*" and a["SS"] != ""
                    _sSubnetId = subnetIdHash[a["SS"].to_s]
                end
                if a["DS"] != "*" and a["DS"] != ""
                    _dSubnetId = subnetIdHash[a["DS"].to_s]
                end
                if _sSubnetId.nil?
                    Logger::logWarn "Did not find subnet id for source subnet name #{a["SS"].to_s} in hash", 2*Logger::loop
                    @@rule_subnetpair_drops += 1
                elsif _dSubnetId.nil?
                    Logger::logWarn "Did not find subnet id for destination subnet name #{a["DS"].to_s} in hash", 2*Logger::loop
                    @@rule_subnetpair_drops += 1
                else
                    _snPair = REXML::Element.new("SubnetPair")
                    _snPair.add_attribute("SourceSubnet", _sSubnetId)
                    _snPair.add_attribute("SourceNetwork", a["SN"])
                    _snPair.add_attribute("DestSubnet", _dSubnetId)
                    _snPair.add_attribute("DestNetwork", a["DN"])
                    _xmlElement.elements << _snPair
                end
            end
            _xmlElement
        end

        def self.createRuleElements(ruleArray, subnetIdHash)
            _rules = REXML::Element.new("Rules")
            ruleArray.each do |x|
                _rule = REXML::Element.new("Rule")
                _rule.add_attribute("Name", x["Name"])
                _rule.add_attribute("Description", "")
                _rule.add_attribute("Protocol", x["Protocol"])
                _netTestMtx = createActOnElements(x["Rules"], subnetIdHash, "NetworkTestMatrix")
                if _netTestMtx.elements.empty?
                    Logger::logWarn "Skipping rule #{x["Name"]} as network test matrix is empty", Logger::loop
                    @@rule_drops += 1
                else
                    _alertConfig = REXML::Element.new("AlertConfiguration")
                    _alertConfig.add_element("Loss", {"Threshold" => x["LossThreshold"] })
                    _alertConfig.add_element("Latency", {"Threshold" => x["LatencyThreshold"]})
                    _exceptions = createActOnElements(x["Exceptions"], subnetIdHash, "Exceptions")
                    _rule.elements << _alertConfig
                    _rule.elements << _netTestMtx
                    _rule.elements << _exceptions
                    _rules.elements << _rule
                end
            end
            _rules
        end
    end

    # This class holds the methods for parsing
    # a config sent via DSC into a hash
    class UIConfigParser
        public

        # Only accessible method
        def self.parse(string)
            begin
                _doc = REXML::Document.new(string)
                if _doc.elements.empty? or _doc.root.nil?
                    Logger::logWarn "UI config string converted to nil/empty rexml doc"
                    return nil
                end

                _configVersion = _doc.elements[RootConfigTag].attributes[Version].to_i
                unless _configVersion == 3
                    Logger::logWarn "Config version #{_configVersion} is not supported"
                    return nil
                else
                    Logger::logInfo "Supported version of config #{_configVersion} found"
                end

                _config = _doc.elements[RootConfigTag + "/" + SolnConfigV3Tag]
                if _config.nil? or _config.elements.empty?
                    Logger::logWarn "found nothing for path #{RootConfigTag}/#{SolnConfigV3Tag} in config string"
                    return nil
                end

                _h = Hash.new
                _h[KeyNetworks] = getNetworkHashFromJson(_config.elements[NetworkInfoTag].text())
                _h[KeySubnets]  = getSubnetHashFromJson(_config.elements[SubnetInfoTag].text())
                _h[KeyAgents]   = getAgentHashFromJson(_config.elements[AgentInfoTag].text())
                _h[KeyRules]    = getRuleHashFromJson(_config.elements[RuleInfoTag].text())
                _h = nil if (_h[KeyNetworks].nil? or _h[KeySubnets].nil? or _h[KeyAgents].nil? or _h[KeyRules].nil?)
                return _h

            rescue REXML::ParseException => e
                Logger::logError "Got XML parse exception at #{e.line()}, #{e.position()}", Logger::resc
                raise "Got XML parse exception at #{e.line()}, #{e.position()}"
            end
            nil
        end

        private

        RootConfigTag   = "Configuration"
        SolnConfigV3Tag = "NetworkMonitoringAgentConfigurationV3"
        NetworkInfoTag  = "NetworkNameToNetworkMap"
        SubnetInfoTag   = "SubnetIdToSubnetMap"
        AgentInfoTag    = "AgentFqdnToAgentMap"
        RuleInfoTag     = "RuleNameToRuleMap"
        Version         = "Version"
        KeyNetworks     = "Networks"
        KeySubnets      = "Subnets"
        KeyAgents       = "Agents"
        KeyRules        = "Rules"

        def self.getNetworkHashFromJson(text)
            begin
                _h = JSON.parse(text)
                _a = Array.new
                _h.each do |key, value|
                    next if value.nil? or value["Subnets"].nil?
                    _network = Hash.new
                    _network["Name"] = key
                    _network["Subnets"] = value["Subnets"]
                    _a << _network
                end
                _a
            rescue JSON::ParserError => e
                Logger::logError "Error in Json Parse in network data: #{e}", Logger::resc
                nil
            end
        end

        def self.getSubnetHashFromJson(text)
            begin
                _h = JSON.parse(text)
            rescue JSON::ParserError => e
                Logger::logError "Error in Json Parse in subnet data: #{e}", Logger::resc
                nil
            end
        end

        def self.getAgentHashFromJson(text)
            begin
                _h = JSON.parse(text)
                _a = Array.new
                _h.each do |key, value|
                    next if value.nil? or !(value["IPs"].is_a?Array)
                    _agent = Hash.new
                    _agent["Guid"] = key
                    _agent["Capability"] = value["Protocol"] unless value["Protocol"].nil?
                    _agent["IPs"] = Array.new
                    value["IPs"].each do |ip|
                        _tempIp = Hash.new
                        _tempIp["IP"] = ip["Value"]
                        # Store agent subnet name as string
                        _tempIp["SubnetName"] = ip["Subnet"].to_s
                        _agent["IPs"] << _tempIp
                    end
                    _a << _agent
                end
                _a
            rescue JSON::ParserError => e
                Logger::logError "Error in Json Parse in agent data: #{e}", Logger::resc
                nil
            end
        end

        def self.getRuleHashFromJson(text)
            begin
                _h = JSON.parse(text)
                _a = Array.new
                _h.each do |key, value|
                    next if value.nil? or
                        !(value["ActOn"].is_a?Array) or
                        !(value["Exceptions"].is_a?Array)
                    _rule = Hash.new
                    _rule["Name"] = key
                    _rule["LossThreshold"] = value["Threshold"]["Loss"]
                    _rule["LatencyThreshold"] = value["Threshold"]["Latency"]
                    _rule["Protocol"] = value["Protocol"] unless value["Protocol"].nil?
                    _rule["Rules"] = value["ActOn"]
                    _rule["Exceptions"] = value["Exceptions"]
                    _a << _rule
                end
                _a
            rescue JSON::ParserError => e
                Logger::logError "Error in Json Parse in rule data: #{e}", Logger::resc
                nil
            end
        end

    end

    # Only function needed to be called from this module
    def self.GetAgentConfigFromUIConfig(uiXml)
        _uiHash = UIConfigParser.parse(uiXml)
        AgentConfigCreator.resetErrorCheck()
        _agentXml = AgentConfigCreator.createXmlFromUIConfigHash(_uiHash)
        _errorStr = AgentConfigCreator.getErrorSummary()
        return _agentXml, _errorStr
    end
end

# NPM Contracts verification for data being uploaded
module NPMContract
    DATAITEM_AGENT = "agent"
    DATAITEM_PATH  = "path"
    DATAITEM_DIAG  = "diagnostics"

    DATAITEM_VALID = 1
    DATAITEM_ERR_MISSING_FIELDS = 2
    DATAITEM_ERR_INVALID_FIELDS = 3
    DATAITEM_ERR_INVALID_TYPE = 4

    CONTRACT_AGENT_DATA_KEYS = ["AgentFqdn",
                                "AgentIP",
                                "AgentCapability",
                                "SubnetId",
                                "PrefixLength",
                                "AddressType",
                                "SubType",
                                "AgentId",
                                "TimeGenerated"]

    CONTRACT_PATH_DATA_KEYS  = ["SourceNetwork",
                                "SourceNetworkNodeInterface",
                                "SourceSubNetwork",
                                "DestinationNetwork",
                                "DestinationNetworkNodeInterface",
                                "DestinationSubNetwork",
                                "RuleName",
                                "TimeSinceActive",
                                "LossThreshold",
                                "LatencyThreshold",
                                "LossThresholdMode",
                                "LatencyThresholdMode",
                                "SubType",
                                "HighLatency",
                                "MedianLatency",
                                "LowLatency",
                                "LatencyHealthState",
                                "Loss",
                                "LossHealthState",
                                "Path",
                                "Computer",
                                "TimeGenerated"]

    CONTRACT_DIAG_DATA_KEYS  = ["Message",
                                "SubType"]

    def self.IsValidDataitem(item, itemType)
        _contract=[]

        if itemType == DATAITEM_AGENT
            _contract = CONTRACT_AGENT_DATA_KEYS
        elsif itemType == DATAITEM_PATH
            _contract = CONTRACT_PATH_DATA_KEYS
        elsif itemType == DATAITEM_DIAG
            _contract = CONTRACT_DIAG_DATA_KEYS
        end

        return DATAITEM_ERR_INVALID_TYPE, nil if _contract.empty?

        item.keys.each do |k|
            return DATAITEM_ERR_INVALID_FIELDS, k if !_contract.include?(k)
        end

        return DATAITEM_VALID, nil if item.length == _contract.length

        _contract.each do |e|
            return DATAITEM_ERR_MISSING_FIELDS, e if !item.keys.include?(e)
        end
        return DATAITEM_VALID, nil
    end

end

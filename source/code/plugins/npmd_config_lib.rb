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
    require 'socket'

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
        def self.createJsonFromUIConfigHash(configHash)
            begin
                _subnetInfo = getProcessedSubnetHash(configHash["Subnets"])
                _doc = {"Configuration" => {}}            
                _doc["Configuration"] ["Agents"] = createAgentElements(configHash["Agents"], _subnetInfo["Masks"])
                _doc["Configuration"] ["Networks"] = createNetworkElements(configHash["Networks"], _subnetInfo["IDs"])
                _doc["Configuration"] ["Rules"] = createRuleElements(configHash["Rules"], _subnetInfo["IDs"])
                _doc["Configuration"] ["Epm"] = createEpmElements(configHash["Epm"])
                _doc["Configuration"] ["ER"] = createERElements(configHash["ER"])

                _configJson = _doc.to_json
                _configJson
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
            _agents = {"Agent" => []}
            agentArray.each do |x|
                _agent = {}
                _agent["Name"] = x["Guid"];
                _agent["Capabilities"] = x["Capability"];
                _agent["IPConfiguration"] = [];
                
                x["IPs"].each do |ip|
                    _ipConfig = {}
                    _ipConfig["IP"] = ip["IP"];
                    _subnetMask = maskHash[ip["SubnetName"]];
                    if _subnetMask.nil?
                        Logger::logWarn "Did not find subnet mask for subnet name #{ip["SubnetName"]} in hash", 2*Logger::loop
                        @@agent_ip_drops += 1
                    else
                        _ipConfig["Mask"] = maskHash[ip["SubnetName"]];
                    end
                    _agent["IPConfiguration"].push(_ipConfig);
                end
                _agents["Agent"].push(_agent);
                if _agents.empty?
                    @@agent_drops += 1

                end
            end
            _agents
        end

        def self.createNetworkElements(networkArray, subnetIdHash)
            _networks = {"Network" => []}
            networkArray.each do |x|
                _network = {}
                _network["Name"] = x["Name"];
                _network["Subnet"] = []
                x["Subnets"].each do |sn|
                    _subnet = {}
                    _subnetId = subnetIdHash[sn]
                    if _subnetId.nil?
                        Logger::logWarn "Did not find subnet id for subnet name #{sn} in hash", 2*Logger::loop
                        @@network_subnet_drops += 1
                    else
                        _subnet["ID"] = subnetIdHash[sn];
                        _subnet["Disabled"]  = ["False"] # TODO
                        _subnet["Tag"]  = "" # TODO
                    end
                    _network["Subnet"].push(_subnet);
                end
                _networks["Network"].push(_network);
                if _network.elements.empty?
                    @@network_drops += 1
                    
                end
            end
            _networks
        end

        def self.createActOnElements(elemArray, subnetIdHash)
            _networkTestMatrix = {"SubnetPair" => []}
            elemArray.each do |a|
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
                    # Process each subnetpair
                    _snPair = {}
                    _snPair["SourceSubnet"] = _sSubnetId
                    _snPair["SourceNetwork"] = a["SN"]
                    _snPair["DestSubnet"] = _dSubnetId
                    _snPair["DestNetwork"] = a["DN"]
                    _networkTestMatrix["SubnetPair"].push(_snPair);
                end
            end
            _networkTestMatrix
        end

        def self.createRuleElements(ruleArray, subnetIdHash)
            _rules = {"Rule" => []}
            ruleArray.each do |x|
                #_rule = REXML::Element.new("Rule")
                _rule = {}
                _rule["Name"] = x["Name"];
                _rule["Description"] = x["Description"]
                _rule["Protocol"] = x["Protocol"];
                _rule["NetworkTestMatrix"] = createActOnElements(x["Rules"], subnetIdHash);
                _rule["AlertConfiguration"] = {};
                _rule["Exceptions"] = createActOnElements(x["Exceptions"], subnetIdHash);
                _rule["DiscoverPaths"] = x["DiscoverPaths"]
                
                if _rule["NetworkTestMatrix"].empty?
                    Logger::logWarn "Skipping rule #{x["Name"]} as network test matrix is empty", Logger::loop
                    @@rule_drops += 1
                else
                    # Alert Configuration
                    _alertConfig = {};
                    _alertConfig["Loss"]  = {"Threshold" => x["LossThreshold"]}
                    _alertConfig["Latency"]  = {"Threshold" => x["LatencyThreshold"]}
                    _rule["AlertConfiguration"].push(_alertConfig);
                    
                end
            end
            _rules
        end

        def self.createEpmElements(epmHash)
            _epm = {"Rules" => {}}
            _epmRules = {"Rule" => []}
            _rule = []
            epmHash.each do |key, rules|
                for i in 0..rules.length-1
                    _ruleHash = Hash.new
                    _iRule = rules[i] # get individual rule
                    _ruleHash["Id"] = _iRule["ID"]
                    _ruleHash["Name"] = _iRule["Name"]
                    _ruleHash["CMResourceId"] = _iRule["CMResourceId"]
                    _ruleHash["Redirect"] = "false"
                    _ruleHash["NetTests"] = (!_iRule["NetworkThresholdLoss"].empty? and !_iRule["NetworkThresholdLatency"].empty?) ? "true" : "false"
                    _ruleHash["AppTests"] = (!_iRule["AppThresholdLatency"].empty?) ? "true" : "false"
                    if (_ruleHash["NetTests"] == "true")
                        _ruleHash["NetworkThreshold"] = {"Loss" => _iRule["NetworkThresholdLoss"], "Latency" => _iRule["NetworkThresholdLatency"]}
                    end

                    if (_ruleHash["AppTests"] == "true")
                        _ruleHash["AppThresholdLatency"] = {"Latency" => _iRule["AppThresholdLatency"]}
                    end

                    # Fill endpoints
                    _epList = _iRule["Endpoints"]
                    _endpointList = {"Endpoint": []}
                    for j in 0.._epList.length-1
                        _epHash = Hash.new
                        _epHash["Id"] = _epList[j]["Id"]
                        _epHash["Target"] = _epList[j]["URL"]
                        _epHash["Port"] = _epList[j]["Port"]
                        _epHash["Protocol"] = _epList[j]["Protocol"]
                        _epHash["PollInterval"] = _iRule["Poll"]
                        _endpointList["Endpoint"].push(_epHash)
                    end
                    _ruleHash["Endpoints"] = _endpointList
                    _rule.push(_ruleHash)
                end
            _epmRules["Rule"] = _rule
            _epm["Rules"] = _epmRules
            _epm
        end

        def self.createERElements(erHash)
            _er = {}
            erHash.each do |key, rules|
                # Fill Private Peering Rules
                if key == "PrivatePeeringRules"
                    _privatePeeringRules = {"PrivateRules" => {}}
                    _ruleList = {"Rule" => []}
                    for i in 0..rules.length-1
                        _pvtRule = Hash.new
                        _iRule = rules[i]
                        _pvtRule["Name"] = _iRule["Name"]
                        _pvtRule["ConnectionResourceId"] = _iRule["ConnectionResourceId"]
                        _pvtRule["CircuitResourceId"] = _iRule["CircuitResourceId"]
                        _pvtRule["CircuitName"] = _iRule["CircuitName"]
                        _pvtRule["VirtualNetworkName"] = _iRule["vNetName"]
                        _pvtRule["Protocol"] = _iRule["Protocol"]

                        _thresholdMap = Hash.new
                        _thresholdMap["Loss"] = Hash.new
                        _thresholdMap["Latency"] = Hash.new
                        _thresholdMap["Loss"]["Threshold"] = iRule[LossThreshold]
                        _thresholdMap["Latency"]["Threshold"] = iRule[LatencyThreshold]
                        _pvtRule["Threshold"] = _thresholdMap

                        _onPremAgents = Hash.new
                        _onPremAgents["Agent"] = []
                        _onPremAgentList = _iRule["OnPremAgents"]
                        for j in 0.._onPremAgentList.length-1
                            _idHash = Hash.new
                            _idHash["ID"] = _onPremAgentList[j]
                            _onPremAgents["Agent"].push(_idHash)
                        end
                        _pvtRule["OnPremAgents"] = _onPremAgents

                        _azureAgents = Hash.new
                        _azureAgents["Agent"] = Hash.new
                        _azureAgentsList = _iRule["AzureAgents"]
                        for k in 0.._azureAgentsList.length-1
                            _azureAgents["Agent"]["ID"] = _azureAgentsList[k]
                        end
                        _pvtRule["AzureAgents"] = _azureAgents

                        _ruleList.push(_pvtRule)
                    end
                    _er.push(_privatePeeringRules)
                end

                # Fill MS Peering Rules
                if key == "MSPeeringRules"
                    _msPeeringRules = Hash.new
                    _ruleList = {"Rule" => []}
                    for i in 0..rules.length-1
                        _msRule = Hash.new
                        _iRule = rules[i]
                        _msRule["Name"] = _iRule["Name"]
                        _msRule["CircuitName"] = _iRule["CircuitName"]
                        _msRule["Protocol"] = _iRule["Protocol"]
                        _msRule["CircuitResourceId"] = _iRule["CircuitResourceId"]

                        _thresholdMap = Hash.new
                        _thresholdMap["Loss"] = Hash.new
                        _thresholdMap["Latency"] = Hash.new
                        _thresholdMap["Loss"]["Threshold"] = iRule[LossThreshold]
                        _thresholdMap["Latency"]["Threshold"] = iRule[LatencyThreshold]
                        _msRule["Threshold"] = _thresholdMap

                        _onPremAgents = Hash.new
                        _onPremAgents["Agent"] = []
                        _onPremAgentList = _iRule["OnPremAgents"]
                        for j in 0.._onPremAgentList.length-1
                            _idHash = Hash.new
                            _idHash["ID"] = _onPremAgentList[j]
                            _onPremAgents["Agent"].push(_idHash)
                        end
                        _msRule["OnPremAgents"] = _onPremAgents

                        _urls = Hash.new
                        _urls["URL"] = []
                        _urlList = _iRule["UrlList"]
                        for k in 0.._urlList.length-1
                            _urlHash = Hash.new
                            _urlHash["Target"] = _urlList[k]["url"]
                            _urlHash["Port"] = _urlList[k]["port"]
                            _urls["URL"].push(_urlHash)
                        end
                        _msRule["URLs"] = _urls
                    end
                    _ruleList.push(_msRule)
                    _er.push(_msPeeringRules)
                end
            end
            _er
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
                
                @agentData = JSON.parse(_config.elements[AgentInfoTag].text())

                _h = Hash.new
                _h[KeyNetworks] = getNetworkHashFromJson(_config.elements[NetworkInfoTag].text())
                _h[KeySubnets]  = getSubnetHashFromJson(_config.elements[SubnetInfoTag].text())
                _h[KeyAgents]   = getAgentHashFromJson(_config.elements[AgentInfoTag].text())
                _h[KeyRules]    = getRuleHashFromJson(_config.elements[RuleInfoTag].text())
                _h[KeyEpm]      = getEpmHashFromJson(_config.elements[EpmInfoTag].text())
                _h[KeyER]       = getERHashFromJson(_config.elements[ERInfoTag].text())
                
                _h = nil if (_h[KeyNetworks].nil? or _h[KeySubnets].nil? or _h[KeyAgents].nil? or _h[KeyRules].nil?)
                return _h

            rescue REXML::ParseException => e
                Logger::logError "Got XML parse exception at #{e.line()}, #{e.position()}", Logger::resc
                raise "Got XML parse exception at #{e.line()}, #{e.position()}"
            end
            nil
        end

        private

        RootConfigTag           = "Configuration"
        SolnConfigV3Tag         = "NetworkMonitoringAgentConfigurationV3"
        NetworkInfoTag          = "NetworkNameToNetworkMap"
        SubnetInfoTag           = "SubnetIdToSubnetMap"
        AgentInfoTag            = "AgentFqdnToAgentMap"
        RuleInfoTag             = "RuleNameToRuleMap"
        EpmInfoTag              = "EPMConfiguration"
        EpmTestInfoTag          = "TestIdToTestMap"
        EpmEndpointInfoTag      = "EndpointIdToEndpointMap"
        EpmAgentInfoTag         = "AgentIdToTestIdsMap"
        ERInfoTag               = "erConfiguration"
        ERPrivatePeeringInfoTag = "erPrivateTestIdToERTestMap";
        ERMSPeeringInfoTag      = "erMSTestIdToERTestMap";
        ERCircuitInfoTag        = "erCircuitIdToCircuitResourceIdMap";
        Version                 = "Version"
        KeyNetworks             = "Networks"
        KeySubnets              = "Subnets"
        KeyAgents               = "Agents"
        KeyRules                = "Rules"
        KeyEpm                  = "Epm"
        KeyER                   = "ER"

        # Hash of {AgentID => {AgentContract}}
        @agentData = {}


        def self.getCurrentAgentId()
            begin
                _agentId = ""
                _ips = []
                addr_infos = Socket.getifaddrs
                addr_infos.each do |addr_info|
                    if addr_info.addr and (addr_info.addr.ipv4? or addr_info.addr.ipv6?)
                        _ips.push(addr_info.addr.ip_address)
                    end
                end

                @agentData.each do |key, value|
                    next if value.nil? or !(value["IPs"].is_a?Array)
                    value["IPs"].each do |ip|
                        for ipAddr in _ips
                            if ip["Value"] == ipAddr
                                _agentId = key
                            end
                        end
                    end
                end
                return _agentId
            end
        end

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
                    _rule["DiscoverPaths"] = value["DiscoverPaths"]
                    _rule["Description"] = value["Description"]
                    _rule["Enabled"] = value["Enabled"]
                    _a << _rule
                end
                _a
            rescue JSON::ParserError => e
                Logger::logError "Error in Json Parse in rule data: #{e}", Logger::resc
                nil
            end
        end

        def self.getEpmHashFromJson(text)
            begin
                _h = JSON.parse(text)
                _agentId = getCurrentAgentId()
                if _agentId.empty?
                    return nil
                else
                    _epmRules = {"Rules" => []}
                    # Check all tests related to current agent id and push their configurations to current agent
                    _testIds = _h[EpmAgentInfoTag][_agentId]
                    _testIds.each do |testId|
                        _test = _h[EpmTestInfoTag][testId]
                        _rule = Hash.new
                        _rule["ID"] = testId
                        _rule["Name"] = _test["Name"]
                        _rule["Poll"] = _test["Poll"]
                        _rule["AppThresholdLatency"] = _test["AppThreshold"]["Latency"]
                        _rule["NetworkThresholdLoss"] = _test["NetworkThreshold"]["Loss"]
                        _rule["NetworkThresholdLatency"] = _test["NetworkThreshold"]["Latency"]
                        _rule["CMResourceId"] = _test["CMResourceId"]

                        # Collect endpoints details
                        _rule["Endpoints"] = []

                        # Get the list of endpoint ids
                        _endpoints = _test["Endpoints"]
                        _endpoints.each do |ep|
                            _endpointHash = Hash.new
                            _endpoint = _test[EpmEndpointInfoTag][ep]
                            _endpointHash["Id"] = ep
                            _endpointHash["URL"] = _endpoint["url"]
                            _endpointHash["Port"] = _endpoint["port"]
                            _endpointHash["Protocol"] = _endpoint["protocol"]
                            _rule["Endpoints"].push(_endpointHash)
                        end
                        _epmRules["Rules"].push(_rule) if !_rule.empty?
                        end
                    end
                    _epmRules if !_epmRules["Rules"].empty?
                end
            rescue JSON::ParserError => e
                Logger::logError "Error in Json Parse in EPM data: #{e}", Logger::resc
                nil
            end
        end

        def self.getERHashFromJson(text)
            begin
                _h = JSON.parse(text)
                _agentId = getCurrentAgentId()

                if _agentId.empty?
                    return nil
                else
                    _erRules = {"PrivatePeeringRules" => [], "MSPeeringRules" => []}
                    # Iterate over OnPrem and Azure Agent Lists to check if this agent is part of this test
                    _privateTestMap = _h[ERPrivatePeeringInfoTag]
                    _microsoftTestMap = _h[ERMSPeeringInfoTag]
                    _circuitIdMap = _h[ERCircuitInfoTag]

                    if _privateTestMap.empty? && _microsoftTestMap.empty?
                        Logger::logError "ER configuration rules deserialization failed.", Logger::resc
                    end

                    # Private Peering Rules
                    if !_privateTestMap.empty?
                        _privateTestMap.each do |key, value|
                            # Get list of onPremAgents in this test
                            _isAgentPresent = false
                            _privateRule = Hash.new
                            _onPremAgents = value["onPremAgents"]
                            _onPremAgents.each do |x|
                                if x == _agentId
                                    # Append this test to ER Config
                                    _isAgentPresent = true
                                    _privateRule = getERPrivateRuleFromUIConfig(key, value)
                                    break;
                                end
                            if !_isAgentPresent
                                _azureAgents = value["azureAgents"]
                                _azureAgents.each do |x|
                                    if x == _agentId
                                        _isAgentPresent = true
                                        _privateRule = getERPrivateRuleFromUIConfig(key, value)
                                        break;
                                    end
                                end
                            end
                            _erRules["PrivatePeeringRules"].push(_privateRule)
                        end
                    end

                    # MS Peering Rules
                    if !microsoftTestMap.empty?
                        _microsoftTestMap.each do |key, value|
                            _microsoftRule = Hash.new
                            _onPremAgents = value["onPremAgents"]
                            _onPremAgents.each do |x|
                                if x == _agentId
                                    # Append this test to ER Config
                                    _isAgentPresent = true
                                    _microsoftRule = getERMicrosoftRuleFromUIConfig(key, value)
                                    break;
                                end
                            _erRules["MSPeeringRules"].push(_microsoftRule)
                            end
                        end
                    end
                    _erRules
                end
            rescue JSON::ParserError => e
                Logger::logError "Error in Json Parse in ER data: #{e}", Logger::resc
                nil
            end 
        end

        def getERPrivateRuleFromUIConfig(key, value)
            _ruleHash = Hash.new
            _ruleHash["Name"] = key
            _ruleHash["Protocol"] = value["protocol"]
            _ruleHash["CircuitId"] = value["circuitId"]
            _ruleHash["LossThreshold"] = value["threshold"]["loss"]
            _ruleHash["LatencyThreshold"] = value["threshold"]["latency"]
            _ruleHash["CircuitName"] = value["circuitName"]
            _ruleHash["vNetName"]= value["vNet"]
            _ruleHash["ConnectionResourceId"]= value["connectionResourceId"]
            _ruleHash["CircuitResourceId"] = _circuitIdMap[value["circuitId"]]
            _ruleHash["OnPremAgents"] = value["onPremAgents"]
            _ruleHash["AzureAgents"] = value["azureAgents"]
            return _ruleHash
        end

        def getERMicrosoftRuleFromUIConfig(key, value)
            _ruleHash = Hash.new
            _ruleHash["Name"] = key
            _ruleHash["CircuitName"] = value["circuitName"]
            _ruleHash["CircuitId"] = value["circuitId"]
            _ruleHash["Protocol"] = value["protocol"]
            _ruleHash["CircuitResourceId"] = _circuitIdMap[value["circuitId"]]
            _ruleHash["LossThreshold"] = value["threshold"]["loss"]
            _ruleHash["LatencyThreshold"] = value["threshold"]["latency"]
            _ruleHash["UrlList"] = value["urlList"]
            return _ruleHash
        end
    end

    # Only function needed to be called from this module
    def self.GetAgentConfigFromUIConfig(uiXml)
        _uiHash = UIConfigParser.parse(uiXml)
        AgentConfigCreator.resetErrorCheck()
        _agentJson = AgentConfigCreator.createJsonFromUIConfigHash(_uiHash)
        _errorStr = AgentConfigCreator.getErrorSummary()
        return _agentJson, _errorStr
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
                                "TimeGenerated",
                                "OSType",
                                "NPMAgentEnvironment"]

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

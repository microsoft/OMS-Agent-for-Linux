require 'socket'

class NPMDTest

    NPMD_CONN_CONFIRM = "NPMDAgent Connected!"
    FAKE_PATH_DATA  = '{"DataItems":[{"SourceNetwork":"abcd", "SourceNetworkNodeInterface":"abcd", "SourceSubNetwork":"abcd", "DestinationNetwork":"abcd", "DestinationNetworkNodeInterface":"abcd", "DestinationSubNetwork":"abcd", "RuleName":"abcd", "TimeSinceActive":"abcd", "LossThreshold":"abcd", "LatencyThreshold":"abcd", "LossThresholdMode":"abcd", "LatencyThresholdMode":"abcd", "SubType":"NetworkPath", "HighLatency":"abcd", "MedianLatency":"abcd", "LowLatency":"abcd", "LatencyHealthState":"abcd","Loss":"abcd", "LossHealthState":"abcd", "Path":"abcd", "Computer":"abcd"}]}'
    FAKE_AGENT_DATA = '{"DataItems":[{"AgentFqdn":"abcd", "AgentIP":"abcd", "AgentCapability":"abcd", "SubnetId":"abcd", "PrefixLength":"abcd", "AddressType":"abcd", "SubType":"NetworkAgent", "AgentId":"abcd"}]}'
    FAKE_EPM_HEALTH_DATA = '{"DataItems":[{ "SubType": "EndpointHealth", "TestName": "googleHTTPTest", "ServiceTestId": "12", "Target": "www.google.com", "EndpointId": "1", "Port": "80", "Protocol": "HTTP", "ServiceLossPercent": "0.000000", "ServiceResponseTime": "387.415000", "ServiceResponseCode": "200", "ServiceResponseHealthState": "Healthy", "ServiceLossHealthState": "Healthy", "ResponseCodeHealthState": "Healthy", "ServiceResponseThresholdMode": "Auto", "Loss": "0.000000", "MedianLatency": "21.904000", "LossHealthState": "Healthy", "LatencyHealthState": "Healthy", "LatencyThresholdMode": "Auto", "LossThresholdMode": "Auto", "TimeGenerated": "2018-05-01 14:55", "TimeSinceActive": "0", "Computer":"abcd" }]}'
    FAKE_EPM_PATH_DATA = '{"DataItems":[{ "SubType":"EndpointPath" "TestName": "googleHTTPTest", "Target": "www.google.com", "ServiceTestId": "12", "EndpointId": "1", "Port": "80", "SourceNetworkNodeInterface": "", "DestinationNetworkNodeInterface": "", "Path": "2404:f801:28:1a:991b:708e:2841:da3a;2404:f801:28:1a:ff::2;2404:f801:0:1:ff:0:62:2;2404:f801:0:2:ff::256;2404:f801:0:2:ff::286;2404:f801:8028:0:ff::22;*;2a01:111:2000:1::b85;*;2001:4860:0:115d::1;*;2404:6800:4009:800::2004", "Loss": "0.000000", "HighLatency": "21.845000", "MedianLatency": "21.845000", "LowLatency": "21.845000", "LossHealthState": "Healthy", "LatencyHealthState": "Healthy", "LossThresholdMode": "Auto", "LatencyThresholdMode": "Auto", "Computer": "abcd", "Protocol": "TCP", "MinHopLatencyList": "1.864000 2.111000 0.975000 0.846000 1.188000 -1.000000 22.001000 -1.000000 22.092000 -1.000000 21.845000", "MaxHopLatencyList": "1.864000 2.111000 0.975000 0.846000 1.188000 -1.000000 22.001000 -1.000000 22.092000 -1.000000 21.845000", "AvgHopLatencyList": "1.864000 2.111000 0.975000 0.846000 1.188000 -1.000000 22.001000 -1.000000 22.092000 -1.000000 21.845000", "TraceRouteCompletionTime": "2018-05-01 15:19:34Z", "TimeGenerated": "2018-05-01 15:05" }]}'
    FAKE_CM_TEST_DATA = '{"DataItems":[{ "SubType": "ConnectionMonitorTestResult", "RecordId": "151d0f93-5b26-49b4-a783-048ace9cd4d0", "ConnectionMonitorResourceId": "/subscriptions/c9acd95d-34fe-4603-b50a-89c27c045b02/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_centraluseuap/connectionMonitors/CmFreqTest", "IngestionWorkspaceResourceId": "/subscriptions/9cece3e3-0f7d-47ca-af0e-9772773f90b7/resourceGroups/ER-Lab/providers/Microsoft.OperationalInsights/workspaces/npm-devEUS2Workspace", "TimeCreated": "2018-09-26T06:08:00Z", "TestGroupName": "TestGroup_123", "TestConfigurationName": "TestConfig123", "SourceType": "OnPremiseMachine", "SourceResourceId": "ARM resource ID goes here", "SourceAddress": "10.10.1.1", "SourceName": "myEUSWorkspace", "SourceAgentId": "151d0f93-5b26-49b4-a783-048ace9cd4d0", "DestinationType": "Address", "DestinationResourceId": "151d0f93-5b26-49b4-a783-048ace9cd4d0", "DestinationAddress": "www.bing.com", "DestinationName": "Bing", "DestinationAgentId": "151d0f93-5b26-49b4-a783-048ace9cd4d0", "Protocol": "HTTP", "DestinationPort": "443", "DestinationIP": "10.10.1.1", "ChecksTotal": "10", "ChecksFailed": "5", "ChecksFailedPercentThreshold": "20", "RoundTripTimeMsThreshold": "10.123", "MinRoundTripTimeMs": "0.675", "MaxRoundTripTimeMs": "0.675", "AvgRoundTripTimeMs": "0.675", "TestResult": "Pass" }]}'
    FAKE_CM_PATH_DATA = '{"DataItems":[{ "SubType": "ConnectionMonitorPath", "RecordId": "151d0f93-5b26-49b4-a783-048ace9cd4d0", "ConnectionMonitorResourceId": "/subscriptions/c9acd95d-34fe-4603-b50a-89c27c045b02/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_centraluseuap/connectionMonitors/CmFreqTest", "IngestionWorkspaceResourceId": "/subscriptions/9cece3e3-0f7d-47ca-af0e-9772773f90b7/resourceGroups/ER-Lab/providers/Microsoft.OperationalInsights/workspaces/npm-devEUS2Workspace", "TimeCreated": "2018-09-26T06:08:00Z", "TestGroupName": "TestGroup_123", "TestConfigurationName": "TestConfig123", "SourceType": "OnPremiseMachine", "SourceResourceId": "ARM resource ID goes here", "SourceAddress": "10.10.1.1", "SourceName": "myEUSWorkspace", "DestinationType": "Address", "DestinationResourceId": "151d0f93-5b26-49b4-a783-048ace9cd4d0", "DestinationAddress": "www.bing.com", "DestinationName": "Bing", "Protocol": "HTTP", "DestinationPort": "443", "ChecksTotal": "10", "ChecksFailed": "5", "ChecksFailedPercentThreshold": "20", "RoundTripTimeMsThreshold": "10.123", "MinRoundTripTimeMs": "0.675", "MaxRoundTripTimeMs": "0.675", "AvgRoundTripTimeMs": "0.675", "PathTestResult": "Pass", "HopAddresses": "2404:f801:28:1a:991b:708e:2841:da3a;2404:f801:28:1a:ff::2;2404:f801:0:1:ff:0:62:2;2404:f801:0:2:ff::256;2404:f801:0:2:ff::286;2404:f801:8028:0:ff::22;*;2a01:111:2000:1::b85;*;2001:4860:0:115d::1;*;2404:6800:4009:800::2004", "HopLinkLatencies": "1.864000 2.111000 0.975000 0.846000 1.188000 -1.000000 22.001000 -1.000000 22.092000 -1.000000 21.845000", }]}'
    FAKE_ER_PATH_DATA = '{"DataItems":[{ "SubType": "ExpressRoutePath", "TimeGenerated": "2019-07-17T11:32:30.817Z", "Circuit": "ER-Lab-ER", "ComputerEnvironment": "Non-Azure", "vNet": "abc123", "Target": "delve.office.com", "PeeringType": "AzurePrivatePeering", "CircuitResourceId": "/subscriptions/9cece3e3-0f7d-47ca-af0e-9772773f90b7/resourceGroups/ER-Lab/providers/Microsoft.Network/expressRouteCircuits/ER-Lab-ER", "ConnectionResourceId": "/subscriptions/9cece3e3-0f7d-47ca-af0e-9772773f90b7/resourceGroups/ER-Lab/providers/Microsoft.Network/connections/ER-Lab-gw-conn", "Path": "10.2.40.10 10.2.40.1 192.168.40.21 192.168.40.22 * 10.10.40.4", "SourceNetworkNodeInterface": "10.2.40.10", "DestinationNetworkNodeInterface": "10.10.40.4", "Loss": "32.163743", "HighLatency": "2.625", "MedianLatency": "2.158", "LowLatency": "1.774", "LossHealthState": "Healthy", "LatencyHealthState": "Healthy", "RuleName": "abcd", "TimeSinceActive": "0", "LossThresholdMode": "Auto", "LatencyThresholdMode": "Auto", "Computer": "ASH-ER-40-VM01", "Protocol": "TCP", "MinHopLatencyList": "0.525000 0.235000 0.386000 -1.000000 1.696000", "MaxHopLatencyList": "0.525000 0.261000 0.399000 -1.000000 2.396000", "AvgHopLatencyList": "0.525000 0.248000 0.392500 -1.000000 2.046000", "TraceRouteCompletionTime": "2019-07-17T11:29:31Z" }]}'

    TEST_ENDPOINT = "tmp_npmd_test/test_agent.sock"

    def initialize
        @clientSock = nil
        @fake_data_uploader_thread = nil
    end

    def run_test_binary
        begin
            @clientSock = UNIXSocket.new(TEST_ENDPOINT)

            # Send in the connection confirmation
            @clientSock.puts NPMD_CONN_CONFIRM
            @clientSock.flush

            @fake_data_uploader_thread = Thread.new(&method(:upload_fake_data))

            loop do
                _line = @clientSock.gets
                sleep(1)
            end
        rescue Exception => e
            @clientSock = nil
        end
    end

    def upload_fake_data
        @clientSock.puts FAKE_AGENT_DATA
        @clientSock.puts FAKE_PATH_DATA
        @clientSock.puts FAKE_AGENT_DATA
    end
end

_testBinary = NPMDTest.new
_testBinary.run_test_binary

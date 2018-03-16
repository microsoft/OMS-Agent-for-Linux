require 'socket'

class NPMDTest

    NPMD_CONN_CONFIRM = "NPMDAgent Connected!"
    FAKE_PATH_DATA  = '{"DataItems":[{"SourceNetwork":"abcd", "SourceNetworkNodeInterface":"abcd", "SourceSubNetwork":"abcd", "DestinationNetwork":"abcd", "DestinationNetworkNodeInterface":"abcd", "DestinationSubNetwork":"abcd", "RuleName":"abcd", "TimeSinceActive":"abcd", "LossThreshold":"abcd", "LatencyThreshold":"abcd", "LossThresholdMode":"abcd", "LatencyThresholdMode":"abcd", "SubType":"NetworkPath", "HighLatency":"abcd", "MedianLatency":"abcd", "LowLatency":"abcd", "LatencyHealthState":"abcd","Loss":"abcd", "LossHealthState":"abcd", "Path":"abcd", "Computer":"abcd"}]}'

    FAKE_AGENT_DATA = '{"DataItems":[{"AgentFqdn":"abcd", "AgentIP":"abcd", "AgentCapability":"abcd", "SubnetId":"abcd", "PrefixLength":"abcd", "AddressType":"abcd", "SubType":"NetworkAgent", "AgentId":"abcd"}]}'

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

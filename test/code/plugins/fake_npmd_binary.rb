require 'socket'

class NPMDTest

    NPMD_CONN_CONFIRM = "NPMDAgent Connected!"
    FAKE_PATH_DATA = '{"DataItems":[{"SubType":"NetworkPath"}]}'
    FAKE_AGENT_DATA = '{"DataItems":[{"SubType":"NetworkAgent"}]}'
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
    end
end

_testBinary = NPMDTest.new
_testBinary.run_test_binary

require 'fluent/test'
require_relative '../../../source/code/plugins/in_npmd_server'
require 'socket'

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

class NPMDServerTest < Test::Unit::TestCase

    TMP_DIR = "tmp_npmd_test"
    FAKE_BINARY_BASENAME = "fake_npmd_binary.rb"
    FAKE_BINARY_FILENAME = File.dirname(__FILE__) + "/#{FAKE_BINARY_BASENAME}"
    RUBY_BINARY_LOCATION = "ruby"
    FAKE_BINARY_INVOCATION = "#{RUBY_BINARY_LOCATION} #{TMP_DIR}/#{FAKE_BINARY_BASENAME}"
    FAKE_BINARY_LOCATION = "#{TMP_DIR}/#{FAKE_BINARY_BASENAME}"
    FAKE_UUID_LOCATION = "#{TMP_DIR}/fake_agent_uuid.txt"
    FAKE_AGENT_ID = "NPMD-FAKE-AGENT-ID"
    FAKE_UNIX_ENDPOINT = "#{TMP_DIR}/test_agent.sock"
    TEST_CONTROL_DATA_FILE = "#{TMP_DIR}/test_agent_config.xml"

    CMD_ENUMERATE_BINARY_INSTANCES = "ps aux | grep fake_npmd"

    CMD_START_NPMD  = "StartNPMD"
    CMD_STOP_NPMD   = "StopNPMD"
    CMD_CONFIG_NPMD = "ConfigNPMD"
    CMD_PURGE_NPMD  = "PurgeNPMD"
    CMD_LOG_NPMD    = "ErrorLog"

    STALE_AGENT_COUNT = 4
    ONE_MIN_IN_MSEC = 6000
    ONE_MSEC        = 0.01

    CONTROL_DATA = '<?xml version="1.0" encoding="utf-16"?><Configuration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3"><NetworkMonitoringAgentConfigurationV3><Metadata>{"Version":3,"Protocol":1,"SubnetUid":1,"AgentUid":1}</Metadata><NetworkNameToNetworkMap>{"Default":{"Subnets":["1","2"]}, "NewOne":{"Subnets":["3"]}}</NetworkNameToNetworkMap><SubnetIdToSubnetMap>{"1":"65.171.0.0/16", "2":"198.165.0.0/21", "3":"162.128.0.0/21"}</SubnetIdToSubnetMap><AgentFqdnToAgentMap>{"1":{"IPs":[{"Value":"65.171.126.72","Subnet":"1"}, {"Value":"65.171.126.73","Subnet":"1"}],"Protocol":"1"}, "2":{"IPs":[{"Value":"65.271.126.72","Subnet":"2"}],"Protocol":"1"}}</AgentFqdnToAgentMap><RuleNameToRuleMap>{"Default":{"ActOn":[{"SN":"*","SS":"*","DN":"*","DS":"*"}],"Threshold":{"Loss":-1.0,"Latency":-1.0},"Exceptions":[],"Protocol":1}}</RuleNameToRuleMap></NetworkMonitoringAgentConfigurationV3></Configuration>'

    TEST_ERROR_LOG_EMIT = "This is a test error log"
    TEST_ERROR_LOG_BINARY_ABSENT = "Binary not found at given location"
    TEST_ERROR_LOG_BINARY_DUPLICATE = "Found both x64 and x32 staging binaries"

    def setup
        Fluent::Test.setup
        FileUtils.mkdir_p(TMP_DIR)
        FileUtils.cp(FAKE_BINARY_FILENAME, "#{TMP_DIR}/#{FAKE_BINARY_BASENAME}")
        f = File.new(TEST_CONTROL_DATA_FILE, "w")
        f.write(CONTROL_DATA)
        f.close
    end

    def teardown
        super
        Fluent::Engine.stop
        FileUtils.rm_rf(TMP_DIR)
    end

    CONFIG = %[
        type npmd
        location_unix_endpoint #{FAKE_UNIX_ENDPOINT}
        location_control_data  #{TEST_CONTROL_DATA_FILE}
        location_agent_binary  #{FAKE_BINARY_LOCATION}
        location_uuid_file     #{FAKE_UUID_LOCATION}
        tag oms.mock.npmd
    ]

    def create_driver(conf=CONFIG)
        _d = Fluent::Test::InputTestDriver.new(Fluent::NPM).configure(conf)
        _d.instance.binary_presence_test_string = "fake_npmd"
        _d.instance.binary_invocation_cmd = FAKE_BINARY_INVOCATION
        _d.instance.num_path_data = 0
        _d.instance.num_agent_data = 0
        _d.instance.num_config_sent = 0
        _d.instance.is_purged = false
        _d
    end

    def create_multiple_test_binary_instances
        (1..STALE_AGENT_COUNT).each do
            _id = Process.spawn(FAKE_BINARY_INVOCATION)
            # puts "Creating fake process with id #{_id}"
            Process.detach(_id)
        end
    end

    def get_num_test_binary_instances
        _resultStr = `#{CMD_ENUMERATE_BINARY_INSTANCES.chomp}`
        _lines = _resultStr.split("\n")
        _count = 0
        _lines.each do |line|
            _userName = line.split()[0]
            if line.include?FAKE_BINARY_BASENAME
                begin
                    _count += 1 if (Process.uid == Process::UID.from_name(_userName))
                rescue ArgumentError
                    # do not ignore case when username is not mapping to UID
                    raise "Got Argumenterror when looking for username:#{_userName} in line #{line}"
                end
            end
        end
        _count
    end

    # Test01: Check if multiple stale instances are getting killed or not
    # Sequence:
    # 1. Create fake UNIX socket for multiple instances to latch onto
    # 2. Create multiple fake binary instances and assert if running
    # 3. Register run post condition as:
    #   (a) Wait for npmdClientSock to be non nil
    #   (b) Assert only one instance of fake binary is running
    # 4. Run the driver
    # 5. Assert that there are no fake binary instances running
    # 6. Assert that npmdClientSock is nil again
    def test_case_01_multiple_stale_instance_deletion
        # Step 1
        File.unlink(FAKE_UNIX_ENDPOINT) if File.exist?FAKE_UNIX_ENDPOINT
        UNIXServer.new(FAKE_UNIX_ENDPOINT)

        # Step 2
        create_multiple_test_binary_instances()
        assert(STALE_AGENT_COUNT <= get_num_test_binary_instances(), "Could not create #{STALE_AGENT_COUNT} instances")

        # Step 3
        d = create_driver
        d.register_run_post_condition {
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) if d.instance.npmdClientSock.nil?
            end
            assert(!d.instance.npmdClientSock.nil?, "NPMD client sock should have been non nil")

            assert_equal(1, get_num_test_binary_instances(), "Multiple instance found when only 1 should be running")
            true
        }

        # Step 4
        d.run

        # Step 5
        assert_equal(0, get_num_test_binary_instances(), "No instance of fake binary should be running")

        # Step 6
        assert(d.instance.npmdClientSock.nil?, "npmdClientSock should be nil as all clients are stopped")
    end

    # Test02: Check if emit is working properly
    # Sequence:
    # 1. Register run post condition as:
    #   (a) Wait for emitted data has both path data and agent data
    # 2. Run the driver
    # 3. Assert that path data has Computer key
    # 4. Assert that agent data has AgentId key
    def test_case_02_emit_path_agent_data
        # Step 1
        d = create_driver
        d.register_run_post_condition {
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) unless (d.instance.num_path_data > 0 and d.instance.num_agent_data > 0)
            end

            assert(d.instance.num_path_data > 0, "Num path data should be greater than 0")
            assert(d.instance.num_agent_data > 0, "Num agent data should be greater than 0")
            true
        }

        # Step 2
        d.run
        emits = d.emits
        assert(emits.length > 0, "There should be at least 1 emitted item by now")
        path_data = nil
        agent_data = nil
        emits.each do |x|
            if x.last.key?("DataItems")
                x.last["DataItems"].each do |z|
                    if z.key?("SubType")
                        if z["SubType"] == "NetworkPath"
                            path_data ||= []
                            path_data << z
                        elsif z["SubType"] == "NetworkAgent"
                            agent_data ||= []
                            agent_data << z
                        end
                    end
                end
            end
        end

        # Step 3
        assert(!path_data.nil?, "Path data should not be nil")
        assert(path_data.length > 0, "There should be at least 1 path data element")
        path_data.each do |x|
            assert(x.key?("Computer"), "All path data elements should have Computer key appended")
        end

        # Step 4
        assert(!agent_data.nil?, "Agent data should not be nil")
        assert(agent_data.length > 0, "There should be at least 1 agent data element")
        agent_data.each do |x|
            assert(x.key?("AgentId"), "All agent data elements should have AgentId key appended")
        end
    end

    # Test03: Check if configuration was sent from startup
    # Sequence:
    # 1. Assert num_config_sent as 0
    # 2. Register run post condition as:
    #   (a) Wait for npmdClientSock to be non nil
    #   (b) Wait for 1 second post this
    # 3. Run the driver
    # 4. Assert num_config_sent to be non zero
    def test_case_03_check_if_config_sent_from_startup
        # Step 1
        d = create_driver
        assert_equal(0, d.instance.num_config_sent, "There should not be any config sent before run")

        # Step 2
        d.register_run_post_condition {
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) if d.instance.npmdClientSock.nil?
            end
            assert(!d.instance.npmdClientSock.nil?, "NPMD client sock should have been non nil")
            sleep(100 * ONE_MSEC)
            true
        }

        # Step 3
        d.run

        # Step 4
        assert(d.instance.num_config_sent > 0, "There should have been atleast one config sent to agent")
    end

    # Test04: Check if configuration is sent via cmd
    # Sequence:
    # 1. Register run post condition as:
    #   (a) Wait for npmdClientSock to be non nil
    #   (b) Note value of num_config_sent
    #   (c) Send config cmd over socket
    # 2. Run the driver
    # 3. Assert increase in num_config_sent
    def test_case_04_check_config_sent_from_cmd
        # Step 1
        d = create_driver
        num_conf_sent = -1
        d.register_run_post_condition {
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) if d.instance.npmdClientSock.nil?
            end
            assert(!d.instance.npmdClientSock.nil?, "NPMD Client sock should have been non nil")

            sleep(100 * ONE_MSEC)

            num_conf_sent = d.instance.num_config_sent
            assert(num_conf_sent > 0, "There should some config sent by now")

            d.instance.process_dsc_command(CMD_CONFIG_NPMD)

            sleep(100 * ONE_MSEC)
            true
        }

        # Step 3
        d.run

        # Step 4
        assert(d.instance.num_config_sent > num_conf_sent, "There should have been at least one more config sent to agent from before")
    end

    # Test05: Check if error log is emitting
    # Sequence:
    # 1. Register run post condition as:
    #   (a) Wait for emit to have error log with "Test" Key
    # 2. Run the driver
    # 3. Assert Test key value in emit is equal to custom log sent
    def test_case_05_error_log_emit
        # Step 1
        d = create_driver
        d.register_run_post_condition {
            sleep(100 * ONE_MSEC)

            d.instance.process_dsc_command("#{CMD_LOG_NPMD}:#{TEST_ERROR_LOG_EMIT}")

            sleep(100 * ONE_MSEC)
            true
        }

        # Step 2
        d.run
        emits = d.emits
        error_logs = nil
        assert(emits.length > 0, "At least some data should have been emitted by now")
        emits.each do |x|
            if x.last.key?("DataItems")
                x.last["DataItems"].each do |z|
                    if z.key?("Message")
                        error_logs ||= []
                        error_logs << z
                    end
                end
            end
        end

        # Step 3
        assert(!error_logs.nil?, "There should have been at least some error logs")
        assert(error_logs.is_a?(Array), "Error logs should be an array")
        assert(error_logs.length > 0, "There should be at least some error logs")
        found_sent_log = false
        error_logs.each do |x|
            if x.key?("Message") and x["Message"] == TEST_ERROR_LOG_EMIT
                found_sent_log = true
                break
            end
        end
        assert(found_sent_log, "Sent log in test should have been seen");
    end

    # Test06: Check start stop of npmd from cmd
    # Sequence:
    # 1. Register run post condition as:
    #   (a) Wait for npmdClientSock to be non nil
    #   (b) Assert only one instance of fake binary is running
    #   (c) Send stop cmd
    #   (d) Assert that no instance of fake binary is running
    #   (e) Assert that npmdClientSock is nil
    #   (f) Send start cmd
    #   (g) Wait for npmdClientSock to be non nil
    #   (h) Assert only one instance of fake binary is running
    # 2. Run the driver
    # 3. Assert that there are no fake binary instances running
    # 4. Assert that npmdClientSock is nil again
    def test_case_06_check_start_stop_from_cmd
        # Step 1
        d = create_driver
        d.register_run_post_condition {
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) if d.instance.npmdClientSock.nil?
            end
            assert(!d.instance.npmdClientSock.nil?, "NPMD client socket should be non nil")
            assert_equal(1, get_num_test_binary_instances(), "Multiple instance found when only 1 should be running")

            d.instance.process_dsc_command(CMD_STOP_NPMD)
            sleep(100 * ONE_MSEC)

            assert_equal(0, get_num_test_binary_instances(), "After stop no instance of binary should be running")
            assert(d.instance.npmdClientSock.nil?, "After stop cmd npmdClientSock should be nil")

            d.instance.process_dsc_command(CMD_START_NPMD)
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) if d.instance.npmdClientSock.nil?
            end

            assert(!d.instance.npmdClientSock.nil?, "NPMD client socket should be non nil")
            assert_equal(1, get_num_test_binary_instances(), "Multiple instance found when only 1 should be running")
            true
        }

        # Step 2
        d.run

        # Step 3
        assert_equal(0, get_num_test_binary_instances(), "No instance of fake binary should be running")

        # Step 4
        assert(d.instance.npmdClientSock.nil?, "npmdClientSock should be nil as all clients are stopped")
    end

    # Test07: Check if purge is working
    # Sequence:
    # 1. Register run post condition as:
    #   (a) Wait for npmdClientSock to be non nil
    #   (b) Send purge command
    #   (c) Wait for npmdClientSock to be nil
    #   (d) Wait for is_purged to be true
    # 2. Run the driver
    # 3. Assert no instance of fake binary running
    # 4. Assert file fake binary does not exist
    # 5. Assert file unix endpoint does not exist
    # 6. Assert uuid file does not exist
    def test_case_07_verify_purge
        # Step 1
        d = create_driver
        d.register_run_post_condition {
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) if d.instance.npmdClientSock.nil?
            end
            assert(!d.instance.npmdClientSock.nil?, "NPMD client socket should be non nil")

            d.instance.process_dsc_command(CMD_PURGE_NPMD)
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) unless d.instance.npmdClientSock.nil?
            end
            assert(d.instance.npmdClientSock.nil?, "NPMD client socket should be nil")

            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) unless d.instance.is_purged
            end
            assert(d.instance.is_purged, "NPMD client socket should be nil")
            true
        }

        # Step 2
        d.run

        # Step 3
        assert_equal(0, get_num_test_binary_instances(), "No instance of fake binary should be running")

        # Step 4
        assert_equal(false, File.exist?(FAKE_BINARY_LOCATION), "File #{FAKE_BINARY_LOCATION} of binary should not exist")

        # Step 5
        assert_equal(false, File.exist?(FAKE_UNIX_ENDPOINT), "File #{FAKE_UNIX_ENDPOINT} representing endpoint should be deleted")

        # Step 6
        assert_equal(false, File.exist?(FAKE_UUID_LOCATION), "File #{FAKE_UUID_LOCATION} should have been deleted")
    end

    # Test08: Check if UUID creation is working
    # Sequence:
    # 1. Delete the uuid file if exists
    # 2. Run the driver without post condition
    # 3. Assert uuid file exists and is not empty
    def test_case_08_verify_uuid_creation
        # Step 1
        File.unlink(FAKE_UUID_LOCATION) if File.exist?(FAKE_UUID_LOCATION)

        # Step 2
        d = create_driver
        d.run

        # Step 3
        assert_equal(true, File.exist?(FAKE_UUID_LOCATION), "UUID file should have been recreated")
    end

    # Test09: Check that UUID is recreated post start after purge
    # Sequence:
    # 1. Create UUID file with new value
    # 2. Register run post condition as:
    #   (a) Wait for npmdClientSock to be non nil
    #   (b) Send purge command
    #   (c) Wait for is_purged to be true
    # 3. Run the driver
    # 4. Assert that uuid file does not exist
    # 5. Run driver without post condition
    # 6. Assert that uuid file exists
    # 7. Assert that uuid value has changed
    def test_case_09_verify_uuid_recreation_post_purge
        # Step 1
        f = File.new(FAKE_UUID_LOCATION, "w")
        f.write(FAKE_AGENT_ID)
        f.close

        # Step 2
        d = create_driver
        d.register_run_post_condition {
            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) if d.instance.npmdClientSock.nil?
            end
            assert(!d.instance.npmdClientSock.nil?, "NPMD client socket should be non nil")

            d.instance.process_dsc_command(CMD_PURGE_NPMD)

            (1..ONE_MIN_IN_MSEC).each do
                sleep(ONE_MSEC) unless d.instance.is_purged
            end
            assert(d.instance.is_purged, "NPMD client socket should be nil")
            true
        }

        # Step 3
        d.run

        # Step 4
        assert_equal(false, File.exist?(FAKE_UUID_LOCATION), "UUID file should not be present after purge")

        # Step 5
        d1 = create_driver
        d1.run

        # Step 6
        assert_equal(true, File.exist?(FAKE_UUID_LOCATION), "UUID file should be recreated post start")

        # Step 7
        f1 = File.new(FAKE_UUID_LOCATION, "r")
        uuid = f1.read()
        f1.close
        assert(uuid != FAKE_AGENT_ID, "UUID should have changed from #{FAKE_AGENT_ID}")
    end

    # Test10: Check that binary not found is handled properly
    # Sequence:
    # 1. Delete the binary file and any staging _x32/_x64 binaries
    # 2. Register run post condition as:
    #   (a) Wait for emit to have at least one error log
    # 3. Run the driver
    # 4. Assert that binary not found error is there in error log
    def test_case_10_binary_not_present
        # Step 1
        File.unlink(FAKE_BINARY_LOCATION) if File.exist?(FAKE_BINARY_LOCATION)
        File.unlink("#{FAKE_BINARY_LOCATION}_x32") if File.exist?("#{FAKE_BINARY_LOCATION}_x32")
        File.unlink("#{FAKE_BINARY_LOCATION}_x64") if File.exist?("#{FAKE_BINARY_LOCATION}_x64")

        # Step 2
        d = create_driver
        d.register_run_post_condition {
            sleep(100 * ONE_MSEC)
            true
        }

        # Step 3
        d.run
        emits = d.emits
        error_logs = nil
        assert(emits.length > 0, "At least some data should have been emitted by now")
        emits.each do |x|
            if x.last.key?("DataItems")
                x.last["DataItems"].each do |z|
                    if z.key?("Message")
                        error_logs ||= []
                        error_logs << z
                    end
                end
            end
        end

        # Step 4
        assert(!error_logs.nil?, "There should have been at least some error logs")
        assert(error_logs.is_a?(Array), "Error logs should be an array")
        assert(error_logs.length > 0, "There should be at least some error logs")
        found_binary_absent_log = false
        error_logs.each do |x|
            if x.key?("Message") and x["Message"] == TEST_ERROR_LOG_BINARY_ABSENT
                found_binary_absent_log = true
                break
            end
        end
        assert_equal(true, found_binary_absent_log, "Binary absent log in test should have been seen");
    end

    # Test11: Check that binary is getting replaced properly by "_x32"
    # Sequence:
    # 1. Copy the binary file by appending "_x32" to name
    # 2. Store the modification time of copy as mtime_x32_1
    # 3. Delete the binary file
    # 4. Run the driver after a wait
    # 5. Assert that copy with "_x32" ending does not exist
    # 6. Assert that binary file now exists
    # 7. Assert that modificiation time of binary file is equal to mtime_x32_1
    # 8. Copy the binary file by appending "_x32" to name again
    # 9. Store the modification time of binary file as mtime_bin_1
    # 10.Run the driver after a wait
    # 11.Assert that copy with "_x32" ending does not exist
    # 12.Assert that the binary file exists
    # 13.Assert that modification time of binary file is newer than mtime_bin_1
    def test_case_11_binary_replaced_by_x32
        # Step 1
        FileUtils.cp(FAKE_BINARY_LOCATION, "#{FAKE_BINARY_LOCATION}_x32") if File.exist?(FAKE_BINARY_LOCATION)

        # Step 2
        mtime_x32_1 = File.mtime("#{FAKE_BINARY_LOCATION}_x32")

        # Step 3
        FileUtils.rm(FAKE_BINARY_LOCATION)
        assert_equal(false, File.exist?(FAKE_BINARY_LOCATION), "Fake binary file should have been deleted")

        # Step 4
        sleep(2)
        d = create_driver
        d.run

        # Step 5
        assert_equal(false, File.exist?("#{FAKE_BINARY_LOCATION}_x32"), "#{FAKE_BINARY_LOCATION}_x32 should have been deleted")

        # Step 6
        assert_equal(true, File.exist?(FAKE_BINARY_LOCATION), "Fake binary file should have been created")

        # Step 7
        mtime_bin = File.mtime(FAKE_BINARY_LOCATION)
        assert(mtime_bin == mtime_x32_1, "The new binary should have a time of modification that is equal to x32 one")

        # Step 8
        FileUtils.cp(FAKE_BINARY_LOCATION, "#{FAKE_BINARY_LOCATION}_x32") if File.exist?(FAKE_BINARY_LOCATION)

        # Step 9
        mtime_bin_1 = File.mtime(FAKE_BINARY_LOCATION)

        # Step 10
        sleep(2)
        d.run

        # Step 11
        assert_equal(false, File.exist?("#{FAKE_BINARY_LOCATION}_x32"), "#{FAKE_BINARY_LOCATION}_x32 should have been deleted again")

        # Step 12
        assert_equal(true, File.exist?(FAKE_BINARY_LOCATION), "Fake binary file should have been created again")

        # Step 13
        mtime_bin_2 = File.mtime(FAKE_BINARY_LOCATION)
        assert(mtime_bin_2 > mtime_bin_1, "The new binary should have a modification that is newer or higher than earlier")
    end

    # Test12: Check that binary is getting replaced properly by "_x64"
    # Sequence:
    # 1. Copy the binary file by appending "_x64" to name
    # 2. Store the modification time of copy as mtime_x64_1
    # 3. Delete the binary file
    # 4. Run the driver after a wait
    # 5. Assert that copy with "_x64" ending does not exist
    # 6. Assert that binary file now exists
    # 7. Assert that modificiation time of binary file is equal to mtime_x64_1
    # 8. Copy the binary file by appending "_x64" to name again
    # 9. Store the modification time of binary file as mtime_bin_1
    # 10.Run the driver after a wait
    # 11.Assert that copy with "_x64" ending does not exist
    # 12.Assert that the binary file exists
    # 13.Assert that modification time of binary file is newer than mtime_bin_1
    def test_case_12_binary_replaced_by_x64
        # Step 1
        FileUtils.cp(FAKE_BINARY_LOCATION, "#{FAKE_BINARY_LOCATION}_x64") if File.exist?(FAKE_BINARY_LOCATION)

        # Step 2
        mtime_x64_1 = File.mtime("#{FAKE_BINARY_LOCATION}_x64")

        # Step 3
        FileUtils.rm(FAKE_BINARY_LOCATION)
        assert_equal(false, File.exist?(FAKE_BINARY_LOCATION), "Fake binary file should have been deleted")

        # Step 4
        sleep(2)
        d = create_driver
        d.run

        # Step 5
        assert_equal(false, File.exist?("#{FAKE_BINARY_LOCATION}_x64"), "#{FAKE_BINARY_LOCATION}_x64 should have been deleted")

        # Step 6
        assert_equal(true, File.exist?(FAKE_BINARY_LOCATION), "Fake binary file should have been created")

        # Step 7
        mtime_bin = File.mtime(FAKE_BINARY_LOCATION)
        assert(mtime_bin == mtime_x64_1, "The new binary should have a time of modification that is equal to x64 one")

        # Step 8
        FileUtils.cp(FAKE_BINARY_LOCATION, "#{FAKE_BINARY_LOCATION}_x64") if File.exist?(FAKE_BINARY_LOCATION)

        # Step 9
        mtime_bin_1 = File.mtime(FAKE_BINARY_LOCATION)

        # Step 10
        sleep(2)
        d.run

        # Step 11
        assert_equal(false, File.exist?("#{FAKE_BINARY_LOCATION}_x64"), "#{FAKE_BINARY_LOCATION}_x64 should have been deleted again")

        # Step 12
        assert_equal(true, File.exist?(FAKE_BINARY_LOCATION), "Fake binary file should have been created again")

        # Step 13
        mtime_bin_2 = File.mtime(FAKE_BINARY_LOCATION)
        assert(mtime_bin_2 > mtime_bin_1, "The new binary should have a modification that is newer or higher than earlier")

    end

    # Test13: Check that "_x64" preceeds "_x32" if both staging are present
    # Sequence:
    # 1. Copy the binary file by appending "_x64" to name
    # 2. Copy the binary file by appending "_x32" to name
    # 3. Register run post condition as:
    #   (a) Wait for emit to have at least one error log
    # 4. Run the driver
    # 5. Assert that both 32, 64 found and picked 64 log is present
    def test_case_13_check_x64_preceeds_x32
        # Step 1
        FileUtils.cp(FAKE_BINARY_LOCATION, "#{FAKE_BINARY_LOCATION}_x64") if File.exist?(FAKE_BINARY_LOCATION)

        # Step 2
        FileUtils.cp(FAKE_BINARY_LOCATION, "#{FAKE_BINARY_LOCATION}_x32") if File.exist?(FAKE_BINARY_LOCATION)

        # Step 3
        d = create_driver
        d.register_run_post_condition {
            sleep(100 * ONE_MSEC)
            true
        }

        # Step 4
        d.run
        emits = d.emits
        error_logs = nil
        assert(emits.length > 0, "At least some data should have been emitted by now")
        emits.each do |x|
            if x.last.key?("DataItems")
                x.last["DataItems"].each do |z|
                    if z.key?("Message")
                        error_logs ||= []
                        error_logs << z
                    end
                end
            end
        end

        # Step 5
        assert(!error_logs.nil?, "There should have been at least some error logs")
        assert(error_logs.is_a?(Array), "Error logs should be an array")
        assert(error_logs.length > 0, "There should be at least some error logs")
        found_binary_duplicate_log = false
        error_logs.each do |x|
            if x.key?("Message") and x["Message"] == TEST_ERROR_LOG_BINARY_DUPLICATE
                found_binary_duplicate_log = true
                break
            end
        end
        assert_equal(true, found_binary_duplicate_log, "Binary duplicate log in test should have been seen");
    end

end

# The npmd input plugin to fluentd
module Fluent
    class NPM < Input
        Fluent::Plugin.register_input('npmd', self)

        unless method_defined?(:router)
            define_method("router") {Fluent::Engine}
        end

        def initialize
            super
            require 'socket'
            require 'fileutils'
            require 'json'
            require 'securerandom'
            require 'etc'

            require_relative 'npmd_config_lib'
        end

        config_param :location_unix_endpoint, :string, :default => "/var/opt/microsoft/omsagent/run/npmdagent.sock"
        config_param :location_control_data,  :string, :default => "/etc/opt/microsoft/omagent/conf/npmd_agent_config.xml"
        config_param :location_agent_binary,  :string, :default => "/opt/microsoft/omsagent/npmd_agent"
        config_param :location_uuid_file,     :string, :default => "/etc/opt/microsoft/omsagent/conf/npmd_agent_guid.txt"
        config_param :tag, :string, :default => "oms.npmd"
        def configure(conf)
            super

            unless @location_unix_endpoint
                raise ConfigError, "'location_unix_endpoint' is needed for agent communication"
            end

            unless @location_control_data
                raise ConfigError, "'location_control_data' is needed to send config to agent"
            end

            unless @location_agent_binary
                raise ConfigError, "'location_agent_binary' is needed to invoke the agent"
            end

            unless @location_uuid_file
                raise ConfigError, "'location_uuid_file' is needed for storing the agent GUID"
            end
        end

        attr_accessor :agentId
        attr_accessor :binary_presence_test_string
        attr_accessor :binary_invocation_cmd
        attr_accessor :npmdClientSock
        attr_accessor :num_path_data, :num_agent_data
        attr_accessor :num_config_sent
        attr_accessor :is_purged
        attr_accessor :omsagentUID, :rootUID

        CMD_START         = "StartNPM"
        CMD_STOP          = "StopNPM"
        CMD_CONFIG        = "Config"
        CMD_PURGE         = "Purge"
        CMD_LOG           = "ErrorLog"

        CONN_AGENT        = 1
        CONN_DSC          = 2
        CONN_UNKNOWN      = 3

        NPMD_CONN_CONFIRM = "NPMDAgent Connected!"

        STOP_SIGNAL       = "SIGKILL"

        RETRY_START_BACKOFF_TIME_SECS   = 900 # 15 minutes
        RETRY_START_WAIT_TIME_SECS      = 5   # 5 seconds
        RETRY_START_ATTEMPTS_PER_BATCH  = 5

        CMD_ENUMERATE_PROCESSES_PREFIX = "ps aux | grep "

        def start
            @binary_presence_test_string = "npmd_agent" if @binary_presence_test_string.nil?
            @binary_invocation_cmd = @location_agent_binary if @binary_invocation_cmd.nil?
            kill_all_agent_instances()
            check_and_update_binaries()
            setup_endpoint()
            @fqdn = get_fqdn()
            check_and_get_guid()
            @server_thread = Thread.new(&method(:server_run))
            @npmdIntendedStop = false
            @stderrFileQueue = Queue.new
            @stop_sync = Mutex.new
            # Initialize to true to prevent wait on first start
            start_npmd_async_retry_thread()
        end

        def shutdown
            Logger::logInfo "Received shutdown notification"
            stop_npmd()
            kill_all_agent_instances()
            @npmdClientSock.close() unless @npmdClientSock.nil?
            @npmdClientSock = nil
            Thread.kill(@server_thread)
            File.unlink(@location_unix_endpoint) if File.exist?@location_unix_endpoint
            File.unlink(@location_agent_binary) if File.exist?@location_agent_binary and (!@do_purge.nil? and @do_purge)
            File.unlink(@location_uuid_file) if File.exist?@location_uuid_file and (!@do_purge.nil? and @do_purge)
            @is_purged = true unless @is_purged.nil?
        end

        def setup_endpoint
            begin
                _dirname = File.dirname(@location_unix_endpoint)
                unless File.directory?(_dirname)
                    FileUtils.mkdir_p(_dirname)
                end
                if File.exists?(@location_unix_endpoint)
                    File.unlink(@location_unix_endpoint)
                end
                @server_obj = UNIXServer.new(@location_unix_endpoint)
            rescue StandardError => e
                log_error "Got error #{e}", Logger::resc
            end
        end

        def get_fqdn
            _ip = nil
            _name = nil
            Socket.ip_address_list.each do |addrinfo|
                next unless addrinfo.ip?
                if addrinfo.ipv4?
                    next if addrinfo.ipv4_loopback? or
                        addrinfo.ipv4_multicast?
                else
                    next if addrinfo.ipv6_linklocal? or
                        addrinfo.ipv6_loopback? or
                        addrinfo.ipv6_multicast?
                end
                _ip = addrinfo.ip_address
                _name = addrinfo.getnameinfo.first
                break if _ip != _name
            end
            _name
        end

        def check_and_get_json(text)
            begin
                _json = JSON.parse(text)
                _json
            rescue JSON::ParserError => e
                Logger::logInfo "Json parsing failed for #{text} because of #{e}", Logger::resc
                nil
            end
        end

        def log_error(msg, depth=0)
            Logger::logError(msg, depth + 1)
            package_and_send_error_log(msg)
        end

        def kill_all_agent_instances
            _cmd = "#{CMD_ENUMERATE_PROCESSES_PREFIX}".chomp + " " + @binary_presence_test_string.chomp
            _resultStr = `#{_cmd}`
            return if _resultStr.nil?
            _lines = _resultStr.split("\n")
            _lines.each do |line|
                if line.include?@binary_presence_test_string
                    _words = line.split()
                    _userName = _words[0]
                    _staleId = _words[1]
                    begin
                        _processOwnerId = Process::UID.from_name(_userName)
                        if (Process.uid == _processOwnerId)
                            Process.kill(STOP_SIGNAL, _staleId.to_i)
                        end
                    rescue Errno::ESRCH
                        # Process already stopped
                    rescue Errno::EPERM
                        # Trying to kill someone else's process?
                        package_and_send_error_log("No perm to kill process with info:#{line}: our uid:#{Process.uid}")
                    rescue ArgumentError
                        # Could not get info on username
                        package_and_send_error_log("Could not process username from info:#{line}: our uid:#{Process.uid}")
                    end
                end
            end
        end

        def npmd_reader
            begin
                begin
                    _line = @npmdClientSock.gets
                    if _line.nil? and !is_npmd_seen_in_ps()
                        @npmdClientSock = nil
                        Logger::logInfo "Exiting reader thread as npmdAgent found stopped"
                        break
                    end
                    next if _line.nil? or _line == " "
                    _json = check_and_get_json(_line.chomp)
                    unless !_json.nil?
                        Logger::logWarn "Sent string to plugin is not a json string", Logger::loop
                    else
                        unless _json.key?("DataItems") and !_json["DataItems"].nil? and _json["DataItems"] != ""
                            Logger::logWarn "No valid data items found in sent json #{_json}", Logger::loop
                        else
                            _uploadData = _json["DataItems"].reject {|x| x["SubType"] == "ErrorLog"}
                            _errorLogs  = _json["DataItems"].select {|x| x["SubType"] == "ErrorLog"}
                            _uploadData.each do |item|
                                if item.key?("SubType")
                                    # Append FQDN to path data
                                    if !@fqdn.nil? and item["SubType"] == "NetworkPath"
                                        @num_path_data += 1 unless @num_path_data.nil?
                                        item["Computer"] = @fqdn
                                        # Append agent Guid to agent data
                                    elsif !@agentId.nil? and item["SubType"] == "NetworkAgent"
                                        @num_agent_data += 1 unless @num_agent_data.nil?
                                        item["AgentId"] = @agentId
                                    end
                                end
                            end
                            emit_upload_data_dataitems(_uploadData) if !_uploadData.nil? and !_uploadData.empty?
                            emit_error_log_dataitems(_errorLogs) if !_errorLogs.nil? and !_errorLogs.empty?
                        end
                    end
                rescue StandardError => e
                    unless is_npmd_seen_in_ps()
                        @npmdClientSock = nil
                        Logger::logInfo "Exiting reader thread. NPMD found stopped", Logger::loop + Logger::resc
                        break;
                    else
                        log_error "Got error while reading data from NPMD: #{e}", Logger::loop + Logger::resc
                    end
                end
            end while !@npmdClientSock.nil?
        end

        def package_and_send_error_log(msg)
            _dataItems = Array.new
            _h = Hash.new
            _h["Message"] = msg
            _dataItems << _h
            emit_error_log_dataitems(_dataItems)
        end

        def emit_error_log_dataitems(dataitems)
            _record = Hash.new
            _record["DataType"] = "HEALTH_ASSESSMENT_BLOB"
            _record["IPName"]   = "LogManagement"
            _record["DataItems"] = dataitems
            router.emit(@tag, Engine.now, _record)
        end

        def emit_upload_data_dataitems(dataitems)
            _record = Hash.new
            _record["DataType"] = "NETWORK_MONITORING_BLOB"
            _record["IPName"]   = "NetworkMonitoring"
            _record["DataItems"] = dataitems
            router.emit(@tag, Engine.now, _record)
        end

        def check_and_update_binaries
            _x32BinPath = "#{@location_agent_binary}_x32"
            _x64BinPath = "#{@location_agent_binary}_x64"
            _x32Present = File.exist?(_x32BinPath)
            _x64Present = File.exist?(_x64BinPath)
            _binPresent = File.exist?(@location_agent_binary)

            if !_binPresent and !_x32Present and !_x64Present
                log_error "Binary not found at given location"
            elsif _x32Present or _x64Present
                if _x32Present and _x64Present
                    log_error "Found both x64 and x32 staging binaries"
                end

                File.unlink(@location_agent_binary) if _binPresent

                if _x64Present
                    FileUtils.mv(_x64BinPath, @location_agent_binary)
                else
                    FileUtils.mv(_x32BinPath, @location_agent_binary)
                end
            end

            File.unlink(_x32BinPath) if File.exist?(_x32BinPath)
            File.unlink(_x64BinPath) if File.exist?(_x64BinPath)
        end

        def check_and_get_guid
            create_new_guid = true
            if File.exist?@location_uuid_file
                f = File.new(@location_uuid_file, "r")
                @agentId = f.read
                f.close

                create_new_guid = false if (!@agentId.nil? and !@agentId.empty?)
            end

            if create_new_guid
                @agentId = SecureRandom.uuid
                f = File.new(@location_uuid_file, "w")
                f.write(@agentId)
                f.close
            end
        end

        def process_dsc_command(cmd)
            return if cmd.nil?
            _req = cmd.chomp

            if _req.start_with?CMD_START
                Logger::logInfo "Processing NPMD Start command"
                start_npmd_async_retry_thread()
            elsif _req.start_with?CMD_STOP
                Logger::logInfo "Processing NPMD Stop command"
                stop_npmd()
            elsif _req.start_with?CMD_CONFIG
                Logger::logInfo "Processing new configuration for NPMD"
                send_config()
            elsif _req.start_with?CMD_PURGE
                Logger::logInfo "Processing NPMD Purge"
                @do_purge = true
                shutdown()
            elsif _req.start_with?CMD_LOG
                Logger::logInfo "Processing error log"
                _ind = _req.index(":")
                _msg = _req[_ind+1..-1]
                unless _ind.nil? or _ind + 1 >= _req.length
                    package_and_send_error_log(_msg)
                end
            else
                Logger::logWarn "Unknown command #{cmd} received from DSC resource provider"
            end
        end

        def is_npmd_seen_in_ps
            return false if @npmdProcessId.nil?
            begin
                Process.getpgid(@npmdProcessId.to_i)
                true
            rescue Errno::ESRCH
                false
            end
        end

        def start_npmd_with_retry(retryCount, cadence, rescheduleTime)
            @stop_sync.synchronize do
                _isStarted = false
                (1..retryCount).each do |x|
                    start_npmd()
                    break if (_isStarted = is_npmd_seen_in_ps())
                    Logger::logInfo "Waiting for #{cadence} seconds before retry"
                    sleep(cadence) unless x == retryCount
                end
                unless _isStarted
                    _delayedStarter = Thread.new {
                        Logger::logInfo "Now waiting for #{rescheduleTime} seconds"
                        sleep(rescheduleTime)
                        start_npmd_with_retry(retryCount, cadence, rescheduleTime)
                    }
                end
            end
        end

        def start_npmd_async_retry_thread
            _npmdStarter = Thread.new {
                start_npmd_with_retry(RETRY_START_ATTEMPTS_PER_BATCH,
                                      RETRY_START_WAIT_TIME_SECS,
                                      RETRY_START_BACKOFF_TIME_SECS)
            }
        end

        def handle_exit(_processId)
            _exitRes = Process.waitpid2(_processId)
            _arr = Array.new
            _doBreak = false

            @stop_sync.synchronize do
                Logger::logInfo "Size of stderrQueue is #{@stderrFileQueue.length()}"
                while @stderrFileQueue.length() > 0
                    begin
                        _h = @stderrFileQueue.pop(true)
                        if !_h.nil? and _h.key?("pid")
                            Logger::logInfo "Processing stderr pid:#{_h["pid"]} and file:#{_h["file"]}"
                            # Stop processing if required pid is seen
                            if _h["pid"] == _processId
                                _doBreak = true
                            # If current pid then reset queue
                            elsif _h["pid"] == @npmdProcessId
                                @stderrFileQueue.clear()
                                @stderrFileQueue << _h
                                Logger::logInfo "Size of stderrQueue is #{@stderrFileQueue.length()}"
                                break
                            end
                            if File.exist?(_h["file"])
                                File.readlines(_h["file"]).each do |line|
                                    _hMessage = Hash.new
                                    _hMessage["Message"] = "PID:#{_h["pid"]}:#{line}"
                                    Logger::logError "STDERR for #{_hMessage["Message"]}"
                                    _arr << _hMessage
                                end
                                File.unlink(_h["file"])
                            end
                            break if _doBreak
                        end
                    rescue ThreadError => e
                        Logger::logInfo "Error in processing stderror file queue: #{e}"
                    end
                end
            end
            emit_error_log_dataitems(_arr) unless _arr.empty?

            # Checking if NPMD exited as planned
            if @npmdIntendedStop
                Logger::logInfo "NpmdAgent exited normally"
            else
                log_error "NpmdAgent ended with exit status #{_exitRes[1]}"
                Logger::logInfo "Restarting NPMD"
                start_npmd_async_retry_thread()
            end
        end

        def start_npmd
            unless is_npmd_seen_in_ps()
                @npmdIntendedStop = false
                _stderrFileName = "#{File.dirname(@location_unix_endpoint)}/stderror_#{SecureRandom.uuid}.log"
                @npmdProcessId = Process.spawn(@binary_invocation_cmd, :err=>_stderrFileName)
                _h = Hash.new
                _h["pid"] = @npmdProcessId
                _h["file"] = _stderrFileName
                @stderrFileQueue << _h
                _t = Thread.new {handle_exit(@npmdProcessId)}
                Logger::logInfo "NPMD Agent running with process id #{@npmdProcessId}"
            else
                Logger::logInfo "Npmd already seen in PS"
            end
        end

        def stop_npmd
            if defined?@npmdProcessId and is_npmd_seen_in_ps()
                @stop_sync.synchronize do
                    @npmdIntendedStop = true
                    Process.kill(STOP_SIGNAL, @npmdProcessId.to_i)
                end
            else
                Logger::logInfo "NPMD agent found already stopped"
            end
        end

        def send_config
            begin # checking for File call errors with this config file
                unless File.exist?(@location_control_data)
                    Logger::logWarn "No file #{@location_control_data} found at location"
                else
                    if defined?@npmdClientSock and !@npmdClientSock.nil?

                        # Read the UI configuration from file location
                        _uiXml = File.read(@location_control_data)
                        if _uiXml.nil? or _uiXml == ""
                            Logger::logWarn "File read at #{@location_control_data} got nil or empty string"
                            return
                        end

                        # Transform the UI XML configuration to agent configuration
                        _agentConfig = NPMDConfig::GetAgentConfigFromUIConfig(_uiXml)
                        if _agentConfig.nil? or _agentConfig == ""
                            Logger::logWarn "Agent configuration transformation returned empty"
                            return
                        end

                        @npmdClientSock.puts _agentConfig
                        @npmdClientSock.flush
                        @num_config_sent += 1 unless @num_config_sent.nil?

                    else
                        Logger::logWarn "NPMD client socket not connected yet!"
                    end
                end
            rescue RuntimeError => e
                log_error "Error while sending config: #{e}", Logger::resc
            end
        end

        def triage_conn(clientSock)
            begin
                @omsagentUID = Process::UID.from_name("omsagent") if @omsagentUID.nil?
                @rootUID = Process::UID.from_name("root") if @rootUID.nil?
                _opt = clientSock.getsockopt(Socket::Constants::SOL_SOCKET,
                                             Socket::Constants::SO_PEERCRED)
                _pid, _euid, _egid = _opt.unpack("i3")

                if _euid == @omsagentUID
                    # Check if this is NPMDAgent binary
                    return CONN_UNKNOWN if @npmdProcessId.nil? or _pid != @npmdProcessId.to_i
                    _rawLine = clientSock.gets
                    return CONN_AGENT if (!_rawLine.nil? and _rawLine.chomp == NPMD_CONN_CONFIRM)
                elsif _euid == @rootUID
                    # This is DSC command
                    return CONN_DSC
                else
                    # Invalid user id
                    _psswd = Etc.getpwuid(_euid)
                    _uname = _psswd.name
                    _fullname = _psswd.gecos
                    log_error "Invalid user:#{_uname}:<#{_fullname}> communicated with NPM plugin"
                end
            rescue => e
                log_error "error: #{e}"
            end
            CONN_UNKNOWN
        end

        def server_run
            unless defined?@server_obj and !@server_obj.nil?
                Logger::logInfo "Server obj was not created properly, Exiting"
            else
                Logger::logInfo "Got FQDN as #{@fqdn} and AgentID as #{@agentId}"
                loop do
                    _client = @server_obj.accept
                    _clientTriage = triage_conn(_client)
                    if _clientTriage == CONN_AGENT
                        Logger::logInfo "NPMD Agent connected"
                        @npmdClientSock = _client
                        @npmdAgentReaderThread = Thread.new{npmd_reader()}
                        send_config()
                    elsif _clientTriage == CONN_DSC
                        _rawLine = _client.gets
                        process_dsc_command(_rawLine) if !_rawLine.nil?
                    end
                end
            end
        end
    end
end

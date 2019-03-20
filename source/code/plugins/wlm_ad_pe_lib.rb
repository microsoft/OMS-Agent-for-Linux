#!/usr/local/bin/ruby
require 'open3'
require 'json'
require 'base64'

module WLM
  class CommandHelper
   
    attr_reader :command
    attr_reader :command_name

    def initialize(command, command_name) 
      @command = command
      @command_name = command_name
      @executed = false
      @is_success = false
    end #def
    
    def execute_command(params)
       Open3.popen3(command % params) { |stdin, stdout, stderr, wait_thr|
        @is_success = wait_thr.value.success?
        @stderr = stderr.read
        @stdout = stdout.read
        @executed = true
      }
    end #def
 
    def is_success? 
      return @is_success if @executed 
      raise "Command not executed"
    end #def
  end #class

  class SystemCtlCommandHelper < CommandHelper
    def initialize
      super("systemctl status %s", "SystemCtl")
    end #def
  end #class

  class PsCommandHelper < CommandHelper 

    def initialize
      super("ps -ef | grep %s", "PS")
    end #def
 
    def is_success?
      if(super)
        if(@stdout.lines.count > 2)
          return true
        end #if
      end #if
      return false
    end #def

  end #class

  class WlmProcessEnumeration 

    attr_reader :config
    attr_reader :commands

    def initialize(config, common=nil, commands=nil)
      require 'base64'
      require_relative 'oms_common'    

      @common = common
      @common = OMS::Common unless @common
      @config = config
      @commands = commands
      @commands = [SystemCtlCommandHelper.new, PsCommandHelper.new] unless @commands
      @data_items = {}

    end #initialize

    def get_data(time, data_type, ip)
      @config.each do |service_config|
        execute_parse(service_config)
      end #each

      @data_items["TimeStamp"] = time 
      @data_items["Host"] = @common.get_hostname
      @data_items["OSType"] = "Linux"
      @data_items["AutoDiscovery"] = "1";
      auto_discovery_data =  {
        "EncodedVMMetadata" => Base64.strict_encode64(@data_items.to_json.to_s)
      }
      return {
        "DataType" => data_type, 
        "IPName" => ip, 
        "DataItems"=> [auto_discovery_data]
      }
    end #discover

    private 
      def execute_parse(service_config)
        @commands.each do |command|
          raise "Invalid command" if !(command.is_a? CommandHelper)
          begin
            service_config["PossibleDaemons"].each do |daemon|
              command.execute_command(daemon) 
              if(command.is_success?)
                @data_items["CommandName"] = command.command_name if @data_items["CommandName"].nil?
                @data_items[service_config["ServiceName"]] = "1"
                return
              end #if
            end #each service_config
          rescue => e
            $log.warn "Command: #{command.command_name} execution failed with Error: #{e}"
          end #begin
        end #each
      end #execute_parse

  end #class

end #module

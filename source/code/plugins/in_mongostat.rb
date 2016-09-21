require 'open3'

module Fluent
  class MongoStatInput < Input
    Fluent::Plugin.register_input('mongostat', self)

    config_param :host, :string, :default => 'localhost'
    config_param :port, :integer, :default => 27017
    config_param :user, :string, :default => nil
    config_param :password, :string, :default => nil
    config_param :auth_database, :string, :default => nil
    config_param :tag, :string, :default => nil
    config_param :run_interval, :string, :default => nil   
  
    def initialize
      super
      require_relative 'mongostat_lib'
      require_relative 'omslog'
    end  
       
    def configure(conf)
      super
      if !@tag 
        raise ConfigError, "'tag' option is required on mongostat input"
      end
    
      if !@user or !@password
        raise ConfigError, "username and password is required"
      end

      if !@auth_database
        raise ConfigError, "Authentication database is required"
      end
    end

    def start
      super
      @mongostat_lib = MongoStatModule::MongoStat.new
      @thread = Thread.new(&method(:run))
    end

    def receive_data(line) 
       begin
        line.chomp!
        transformed_record = @mongostat_lib.transform_and_wrap(line) 
        time = Time.now
        if time && transformed_record
          tag=@tag
          router.emit(tag, time, transformed_record)
        end
      rescue => e
        $log.warn line.dump, error: e.to_s
      end
    end

    def run
      begin
      run_mongostat = "mongostat --host #{@host} --port #{@port} -u #{@user} -p #{@password} --authenticationDatabase #{auth_database} --all"
      if @run_interval
        run_mongostat += " #{@run_interval}"
      end
      Open3.popen3(run_mongostat) {|writeio, readio, errio, wait_thread|
        writeio.close
        while line = readio.gets
            receive_data(line)
        end
        
        while line = errio.gets
          $log.error "#{line}"
        end
        wait_thread.value
      }
      rescue Errno::ENOENT
        OMS::Log.error_once("Mongostat is not installed on this machine.")
      rescue
        OMS::Log.error_once("in_mongostat failed to run or shutdown child prcess #{$!.to_s}")
      end
    end
   
    def shutdown
      super
      @thread.join
    end
  end
 
end

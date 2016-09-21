module Fluent
  class MysqlWorkloadInput < Fluent::Input
    Plugin.register_input('mysql_workload', self)

    def initialize
      require_relative 'mysql_workload_lib'
      super
    end

    config_param :host, :string, :default => 'localhost'
    config_param :port, :integer, :default => 3306
    config_param :username, :string, :default => 'root'
    config_param :password, :string, :default => nil, :secret => true
    config_param :database, :string, :default => nil
    config_param :encoding, :string, :default => 'utf8'
    config_param :interval, :time, :default => '1m'
    config_param :tag, :string

    def configure(conf)
      super
    end

    def start
      super
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      super
      if @mysql_lib != nil
        @mysql_lib.close_connection
      end
      Thread.kill(@thread)
    end

    def run
      @mysql_lib = MysqlWorkload_Lib.new(@host, @port, @username, @password, @database, @encoding)
      loop do
        time = Time.now.to_f
        wrapper = @mysql_lib.enumerate(time)
        router.emit(@tag, Engine.now, wrapper) if wrapper
        sleep @interval
      end
    end

  end
end

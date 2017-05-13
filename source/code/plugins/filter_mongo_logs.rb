module Fluent
  class MongoLogsFilter < Filter

    Fluent::Plugin.register_filter('filter_mongo_logs', self)

    def initialize
      require 'socket'
      super
    end

    def configure(conf)
      super
    end

    def start
      super
    end

    def shutdown
      super
    end

    def filter(tag, time, record)
      record["ResourceName"]= 'MongoDB'
      record["Computer"] = IPSocket.getaddress(Socket.gethostname)
      record["ResourceId"] = Socket.gethostname

      record
    end
  end
end
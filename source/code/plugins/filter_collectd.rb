require_relative 'collectd_lib'
require_relative 'oms_common'

module Fluent

  class CollectdFilter < Filter
    Fluent::Plugin.register_filter('filter_collectd', self)

    config_param :collectd, :array, :default => []

    def configure(conf)
      super
    end

    def start
      super
      @collectd_lib = CollectdModule::Collectd.new
      @hostname = OMS::Common.get_hostname or "Unknown host"
    end

    def shutdown
      super
    end

    def filter(tag, time, record)
      return transformed_record = @collectd_lib.transform_and_wrap(record, @hostname)
    end
  end
end


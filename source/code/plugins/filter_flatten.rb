require_relative 'flattenjson_lib'

module Fluent

  class FlattenFilter < Filter
    Fluent::Plugin.register_filter('filter_flatten', self)

    #Usage:
    #  <filter>
    #    type filter_flatten
    #    select record['apps']['app']
    #  </filter>
    config_param :select, :string, :default => 'record'

    def configure(conf)
      super
    end

    def start
      super
      @flattenjson_lib = OMS::FlattenJson.new
    end

    def shutdown
      super
    end

    def filter_stream(tag, es)
      mes = MultiEventStream.new

      es.each do |time, record| 
        @flattenjson_lib.select_split_flatten(time, record, @select, mes)
      end

      return mes
    end
  end  # class
end  # module

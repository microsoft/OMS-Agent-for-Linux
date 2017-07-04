module Fluent
  class SCOMConverter < Filter
  # Filter plugin to covert the input records to SCOM event format
  Fluent::Plugin.register_filter('filter_scom_converter', self)

  desc 'event number to be sent to SCOM'
  config_param :event_id, :string, :default => nil
  desc 'event description to be sent to SCOM'
  config_param :event_desc, :string, :default => nil

  def initialize()
    super
    require_relative 'scom_common'
  end

  def configure(conf)
    super
    raise ConfigError, "Configuration does not have corresponding event ID" unless @event_id
  end

  def start()
    super
  end

  def shutdown()
    super
  end

  def filter(tag, time, record)
    $log.debug "Generating SCOM Event with id: #{@event_id} and data: #{record}" 
    result = SCOM::Common.get_scom_record(time, @event_id, @event_desc, record)
    result
  end
  
  end # class SCOMConverter
end # module Fluent
  
  


module Fluent

  class WlmOmsOmiFilter < Filter

    Plugin.register_filter('wlm_oms_omi', self)

    config_param :discovery_time_file, :string

    def configure(conf)
      super
    end

    def start
      super
    end

    def filter(tag, time, record)
      if File.exist? (@discovery_time_file)
        return record
      else
        return nil
      end #if

    end #filter

  end #class

end #module


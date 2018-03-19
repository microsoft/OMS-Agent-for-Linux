
require_relative 'security_baseline_lib'
require_relative 'oms_common' 

module Fluent
  class SecurityBaselineFilter < Filter

    Fluent::Plugin.register_filter('filter_security_baseline', self)

    def configure(conf)
        super
        # Do the usual configuration here
        @hostname = OMS::Common.get_hostname or "Unknown host"
    end

    def start
        super
        # This is the first method to be called when it starts running
        # Use it to allocate resources, etc.
    end

    def shutdown
        super
        # This method is called when Fluentd is shutting down.
        # Use it to free up resources, etc.
    end

    def filter(tag, time, record)       
        # Create Security Baseline and Security Baseline Summary blobs based on omsbaseline tool scan & assessment results
        security_baseline = OMS::SecurityBaseline.new(@log)
        security_baseline_blob, security_baseline_summary_blob = security_baseline.transform_and_wrap(record, @hostname, time)

        if !security_baseline_summary_blob.nil?
            # Send Security Baseline Summary to FuentD pipeline.
            # The data is formatted in correct ODS format and no more handling  is required
            Fluent::Engine.emit("oms.security_baseline_summary", time, security_baseline_summary_blob)
        end

        return security_baseline_blob
    end # filter
  end # class
end # module

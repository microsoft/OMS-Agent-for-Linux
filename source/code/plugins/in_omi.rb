#!/usr/local/bin/ruby

module Fluent

class OMIInput < Input
    Fluent::Plugin.register_input('omi', self)

    @omi_interface = nil

    def initialize
        super
        require 'json'
        require_relative 'Libomi'
    end

    config_param :items, :array, :default => []
    config_param :run_interval, :time, :default => nil
    config_param :tag, :string, :default => "omi.data"
    def configure (conf)
        super
    end

    def enumerate
        time = Time.now.to_f
        record_txt = @omi_interface.enumerate(@items)
        record = JSON.parse record_txt

        if record.length > 0
            router.emit(@tag, time, record)
        end
    end

    def start
        @omi_interface = Libomi::OMIInterface.new
        @omi_interface.connect
        if @run_interval
            @finished = false
            @condition = ConditionVariable.new
            @mutex = Mutex.new
            @thread = Thread.new(&method(:run_periodic))
        else
            enumerate
        end
    end

    def shutdown
        if @run_interval
            @mutex.synchronize {
                @finished = true
                @condition.signal
            }
            @thread.join
        end
        @omi_interface.disconnect
    end

    def run_periodic
        @mutex.lock
        done = @finished
        until done
            @condition.wait(@mutex, @run_interval)
            done = @finished
            @mutex.unlock
            if !done
                enumerate
            end
            @mutex.lock
        end
        @mutex.unlock
    end

end # OMIInput


end # module

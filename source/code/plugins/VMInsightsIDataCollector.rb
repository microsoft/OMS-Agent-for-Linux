# frozen_string_literal: true

module VMInsights

    # Design assumptions:
    # 1. Changing the number of active CPUs requires a system reboot.
    # 2. Assumption #1 is something that could change as virtualization technology evolves.
    # So:
    # 1. Gather the value once and cache it.
    # 2. Design the API so that the number of active CPUs is part of the data requested for each sample.

    class IDataCollector

        # return:
        #   Hash with elements:
        #       :total_time - cummulative system total time
        #       :idle - cummulative system idle time
        def baseline
            not_implemented
        end

        def start_sample
            not_implemented
        end


        # returns: free, total
        def get_available_memory_kb
            not_implemented
        end

        # returns: cummulative total time, cummulative idle time
        def get_cpu_idle
            not_implemented
        end

        # returns:
        #   number of CPUs available for scheduling tasks
        # raises:
        #   Unavailable if not available
        def get_number_of_cpus
            not_implemented
        end

        # return:
        #   An array of objects with methods:
        #       mount_point
        #       size_in_bytes
        #       free_space_in_bytes
        #       device_name
        def get_filesystems
            not_implemented
        end

        # given:
        #   block device name
        # returns:
        #   an object with methods:
        #       reads           since last call or baseline
        #       bytes_read      since last call or baseline, nil if not available
        #       writes          since last call or baseline
        #       bytes_written   since last call or baseline, nil if not available
        #       delta_time      time, in seconds, since last sample
        # raises:
        #   Unavailable if not available
        # reference:
        #   https://www.mjmwired.net/kernel/Documentation/iostats.txt
        def get_disk_stats(dev)
            # /sys/class/block/sda2/stat
            not_implemented
        end

        # returns:
        #   An array of objects with methods:
        #       device
        #       bytes_received  since last call or baseline
        #       bytes_sent      since last call or baseline
        #       delta_time      time, in seconds, since last sample
        #   Note: Only devices that are "UP" or had activity are included
        def get_net_stats
            not_implemented
        end

        def end_sample
            not_implemented
        end

        class Unavailable < StandardError
            def initialize(msg)
                super msg
            end
        end
    private
        def not_implemented
            raise RuntimeError, "not implemented"
        end
    end # DataCollector

end #module

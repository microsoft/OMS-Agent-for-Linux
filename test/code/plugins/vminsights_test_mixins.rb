# frozen_string_literal: true

SourcePath = File.join '..', '..', '..', 'source', 'code', 'plugins'

module VMInsights

    module StringUtils
        def parse_iso8601(ts)
            return nil unless (String === ts)
            match_data = @@iso8601_regex.match ts
            return nil unless match_data

            year = match_data[1].to_i
            month = match_data[2].to_i
            day = match_data[3].to_i

            hour = match_data[4].to_i
            minutes = match_data[5].to_i
            seconds = match_data[6].to_r

            tz_offset = match_data[7]
            off_sec   = if tz_offset == 'Z'
                            0
                        else
                            i = (tz_offset + "000000")[1,6].to_i
                            (tz_offset[0] == '+' ? 1 : -1) * ((((((i / 10000) % 100) * 60) + ((i / 100) % 100)) * 60) + (i % 100))
                        end

            Time.new year, month, day, hour, minutes, seconds, off_sec
        end

    private

        @@iso8601_regex = /([0-9]{4})-([01][0-9])-([0123][0-9])T([012][0-9]):([0-5][0-9]):([0-6][0-9](?:\.[0-9]{0,3})?)([+-Z][0-9]{0,6})/
    end # module StringUtils

    module RandomUUID
        def random_uuid
            @@rand.bytes(16)
        end
    private
        @@rand = Random.new(Time.now.tv_usec)
    end # module RandomUUID

    module FileUtils

        def make_temp_directory(parent='.')
            result = File.join(parent, "tmpdir#{Random.rand(0x7ffff)+0x80000}")
            Dir.mkdir result, 0777
            at_exit {
                recursive_delete result
            }
            result
        end

        def make_temp_file(dir,pfx="file",sfx="tmp")
            result = File.join(dir, "#{pfx}#{Random.rand(0x7ffff)+0x80000}.#{sfx}")
            File.new(result, "w", 0666).close
            at_exit {
                File.delete result if File.exist? result
            }
            result
        end

        def recursive_delete(dir)
            return unless File.exist? dir
            Dir.foreach(dir) { |entry|
                path = File.absolute_path(entry, dir)
                if (File.directory?(path) && ! File.symlink?(path))
                    recursive_delete(path) unless DotDirectories.include? entry
                else
                    File.delete path
                end
            }
            Dir.rmdir dir
        end

        DotDirectories = [ '.', '..' ]
    end # FileUtils

    class SyncPoint
        def initialize
            @mutex = Mutex.new
            @condvar = ConditionVariable.new
            @count = 0
        end

        def get_wait_handle(how_many=1)
            @mutex.synchronize {
                WaitHandle.new(@count+how_many) { |target, timeout|
                    (next true) if target <= @count
                    @mutex.synchronize {
                        if timeout
                            limit = Time.now + timeout
                            while @count < target
                                delta = limit - Time.now
                                break if delta <= 0
                                @condvar.wait @mutex, delta
                            end
                            next @count >= target
                        end

                        while @count < target
                            @condvar.wait @mutex
                        end
                        next true
                    }
                }
            }
        end

        def signal
            @mutex.synchronize {
                @count += 1
                @condvar.broadcast
            }
        end

        def to_s
            "SyncPoint(#{@count})"
        end

    private

        class WaitHandle
            def initialize(target, &block)
                @target = target
                @block = block
            end

            def wait(timeout=nil)
                @block.call(@target, timeout)
            end

            def get_wait_handle
                WaitHandle.new(@target+1, &@block)
            end

            def to_s
                "WaitHandle(#{@target}, #{@block})"
            end

            alias inspect to_s
        end # class WaitHandle

    end # class SyncPoint

end # module VMInsights

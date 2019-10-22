# frozen_string_literal: true

module VMInsights

private

    class MockLogBase

        class Severity
            def <=>(o)
                o && (v - o.v)
            end
            def succ
                ALL_INDEX[v + 1]
            end
            def to_s
                @s
            end
            alias inspect to_s
            def Severity.[](*strings)
                strings.each { |s| ALL_HASH[s] }
            end
        protected
            attr_reader :v
        private
            def initialize(v, s)
                @v = v
                @s = s.dup.freeze
            end
            ALL_INDEX = []
            ALL_HASH = Hash.new { |h, str|
                v = h.size
                sev = Severity.new v, str
                h[str] = sev
                ALL_INDEX[v] = sev
                Severity.const_set str, sev
            }
            Severity["BELOW", "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "ABOVE"]
        end

    private
        BELOW=Severity::BELOW
        ABOVE=Severity::ABOVE

    public
        TRACE=Severity::TRACE
        DEBUG=Severity::DEBUG
        INFO=Severity::INFO
        WARN=Severity::WARN
        ERROR=Severity::ERROR

        ALL=(BELOW..ABOVE)
        NONE=(BELOW..BELOW)

        TRACE_AND_ABOVE=(TRACE..ABOVE)
        DEBUG_AND_ABOVE=(DEBUG..ABOVE)
        INFO_AND_ABOVE=(INFO..ABOVE)
        WARN_AND_ABOVE=(WARN..ABOVE)
        ERROR_AND_ABOVE=(ERROR..ABOVE)

        TRACE_AND_BELOW=(BELOW..TRACE)
        DEBUG_AND_BELOW=(BELOW..DEBUG)
        INFO_AND_BELOW=(BELOW..INFO)
        WARN_AND_BELOW=(BELOW..WARN)
        ERROR_AND_BELOW=(BELOW..ERROR)

        def initialize(ignore_range=(TRACE..DEBUG), flunk_range=WARN_AND_ABOVE)
            @ignore_range = ignore_range
            @flunk_range = flunk_range
            @flunked_logs = []
        end

        attr_accessor :ignore_range, :flunk_range

        def trace(*msg, &block)
puts __FILE__, __LINE__, msg, block
            log_message TRACE, msg, block
        end

        def trace_backtrace(bt=$!.backtrace)
            log_backtrace TRACE, bt
        end

        def debug(*msg, &block)
puts __FILE__, __LINE__, msg, block
            log_message DEBUG, msg, block
        end

        def debug_backtrace(bt=$!.backtrace)
            log_backtrace DEBUG, bt
        end

        def info(*msg, &block)
puts __FILE__, __LINE__, msg, block
            log_message INFO, msg, block
        end

        def info_backtrace(bt=$!.backtrace)
            log_backtrace INFO, bt
        end

        def warn(*msg, &block)
puts __FILE__, __LINE__, msg, block
            log_message WARN, msg, block
        end

        def warn_backtrace(bt=$!.backtrace)
            log_backtrace WARN, bt
        end

        def error(*msg, &block)
puts __FILE__, __LINE__, msg, block
            log_message ERROR, msg, block
        end

        def error_backtrace(bt=$!.backtrace)
            log_backtrace ERROR, bt
        end

        def check
            raise @flunked_logs.join("\n") unless @flunked_logs.empty?
        end

        def to_s
            @flunked_logs.empty? ?
            "" :
            "Flunked Logs:\n" + @flunked_logs.join("\n")
        end

    private

        def log_message(severity, msgs, block)
            return if ignore_range.cover? severity
            msgs << block.call if block
            if (flunk_range.cover? severity)
                @flunked_logs << "Unexpected log message: sev=#{severity} message='#{msgs}'"
            else
                handle_message severity, msgs
            end
        end

        def log_backtrace(severity, bt)
            return if ignore_range.cover? severity
            if (flunk_range.cover? severity)
                bt_str = bt.join "\n\t\t"
                @flunked_logs << "Unexpected log backtrace: sev=#{severity}\n\tbacktrace=#{bt_str}"
            else
                handle_backtrace severity, bt
            end
        end

        def handle_message(severity, msg)
            raise NotImplemented
        end

        def handle_backtrace(severity, bt)
            raise NotImplemented
        end

    end # class MockLogBase

public

    class MockLog < MockLogBase

        def initialize(*args)
            super
            @logs = []
            @message_handler_hook = @backtrace_handler_hook = @@null_handler
            @mutex = Mutex.new
        end

        def set_message_hook(&block)
            old_hook = @message_handler_hook
            @message_handler_hook = block || @@null_handler
            old_hook
        end

        def set_backtrace_hook(&block)
            old_hook = @backtrace_handler_hook
            @backtrace_handler_hook = block || @@null_handler
            old_hook
        end

        def mark(msg, *data)
            @mutex.synchronize {
                @logs << { :mark => msg, :data => data }
            }
        end

        def clear
            @mutex.synchronize {
                @logs.clear
            }
        end

        def empty?
            @mutex.synchronize {
                @logs.empty?
            }
        end

        def size
            @mutex.synchronize {
                @logs.size
            }
        end

        def each
            @mutex.synchronize {
                @logs.each { |e| yield e.dup }
            }
        end

        def to_a
            @mutex.synchronize {
                @logs.map { |e| e.dup }
            }
        end

        def to_s
            @mutex.synchronize {
                result = String.new "Log(#{@logs.size}):\n"
                @logs.each { |e| result << "    #{e}\n" }
                result + super
            }
        end

private

        def handle_message(severity, msgs)
            unless @message_handler_hook[severity, msgs]
                @mutex.synchronize {
                    @logs << { :severity => severity, :messages => msgs }
                }
            end
        end

        def handle_backtrace(severity, bt)
            unless @backtrace_handler_hook[severity, bt]
                @mutex.synchronize {
                    @logs << { :severity => severity, :backtrace => bt }
                }
            end
        end

        @@null_handler = Proc.new { false }

    end # class MockLog

end # module VMInsights

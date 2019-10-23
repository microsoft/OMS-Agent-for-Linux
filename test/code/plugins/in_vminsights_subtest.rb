# frozen_string_literal: true

require 'test/unit'

require 'tempfile'

require_relative 'vminsights_test_mixins.rb'
require_relative 'vminsights_test_mocklog.rb'

module Fluent

    require_relative File.join(SourcePath, 'in_vminsights.rb')

    class VMInsights_test < ::Test::Unit::TestCase

        def initialize(*args)
            super(*args)
            @clean_up = []
            Plugin.register_output("mock_output", MockOutput)
        end

        def setup
            @mock_log = ::VMInsights::MockLog.new ::VMInsights::MockLog::NONE
            $log = @mock_log

            @object_under_test = VMInsights.new
            @mock_tag = String.new "ThE.TaG.NaMe" # to use as a filter match pattern, can't have spaces in it
            @mock_metric_engine = MockMetricsEngine.new

            @conf = {
                "tag" => @mock_tag,
                :MockMetricsEngine => @mock_metric_engine,
            }

            mock_system_config_input = MockConf.new
            system_config = SystemConfig.create(mock_system_config_input)
            Engine.init system_config
            Engine.root_agent.add_match "mock_output", @mock_tag, {}

            @mock_log.clear     # remove any residue created by the test framework

        end

        def teardown
            @conf = nil
            @clean_up.each { |f|
                next unless File.exist? f
                recursive_delete f
            }

            @mock_tag = nil
            @object_under_test = nil

            begin
                @mock_log.check
            rescue Exception
                puts "#{@mock_log}"
                raise
            end
            @mock_log = nil
            $log = nil
        end

        def test_default_configure
            router = @object_under_test.router
            assert_nil router

            @object_under_test.configure @conf

            assert_equal @mock_tag, @object_under_test.tag
            assert_equal 60, @object_under_test.poll_interval
            router = @object_under_test.router
            assert_not_nil router
            assert_equal [], MockOutput.instance.messages
            logs = @mock_log.to_a
            assert logs.size == 0, Proc.new() { @mock_log.to_s }
        end

        def test_metric_engine_upload_start_stop
            @object_under_test.configure @conf
            logs = @mock_log.to_a
            assert logs.size == 0, Proc.new() { @mock_log.to_s }

            begin
                @object_under_test.start
                sleep(3)
            ensure
                @object_under_test.shutdown
            end

            assert_logs

        end

        def test_metric_data_uploaded
            assert_equal [], MockOutput.instance.messages

            @conf["poll_interval"] = 1
            @object_under_test.configure @conf
            assert_equal 1, @object_under_test.poll_interval
            logs = @mock_log.to_a
            assert logs.size == 0, Proc.new() { @mock_log.to_s }

            begin
                expected_data = [ "mock data", "atad kcom" ]
                @object_under_test.start
                (1..3).each { |i| sleep(1) unless @mock_metric_engine.running? }

                assert @mock_metric_engine.running?

                count_before = MockOutput.instance.messages.size
                @mock_metric_engine.add_data [ expected_data ]
                time_before = Engine.now
                (1..3).each { |i| sleep(1) if MockOutput.instance.messages.size == count_before }
                time_after = Engine.now

                assert_equal (count_before + 1), MockOutput.instance.messages.size

                tag, time, wrapper = *(MockOutput.instance.messages[count_before])

                assert_equal @mock_tag, tag

                assert_not_nil time
                assert_in_range(time_before, time, time_after) { |v| v.strftime('%F %T.%N%z') }

                assert_kind_of Hash, wrapper
                text = wrapper.inspect
                assert_equal 'INSIGHTS_METRICS_BLOB', wrapper['DataType'], text
                assert_equal 'VMInsights', wrapper['IPName'], text

                array = wrapper['DataItems']
                text = array.inspect
                assert_kind_of Array, array
                assert_equal expected_data.size, array.size, text
                assert_equal expected_data, array

            ensure
                @object_under_test.shutdown
                assert_logs

                @mock_log.clear

                refute @mock_metric_engine.running?

                @mock_metric_engine.check
            end
        end

    private

        def make_temp_directory name
            Dir.mkdir name
            File.chmod 0700, name # not effective on Windows
            @clean_up << name
        end

        def recursive_delete name
            if (File.symlink? name) || (! File.directory? name)
                File.delete name
                return nil
            end

            Dir.new(name).each { |f|
                case f
                    when '.', '..'
                        next
                    else
                        recursive_delete File.join(name, f)
                end
            }
            Dir.rmdir name
            nil
        end

        def assert_in_range min, t, max, &block
            block = (Proc.new() { |v| v }) unless block
            assert min <= t, Proc.new() { "min=#{block[min]} actual=#{block[t]}" }
            assert t <= max, Proc.new() { "max=#{block[max]} actual=#{block[t]}" }
        end

        def assert_logs
            logs = @mock_log.to_a
            assert_equal 3, logs.size, logs.to_s
            expected = [ "starting ...", "stopping ...", "... stopped" ]
            expected.each_index { |i|
                log = logs[i]
                assert_equal ::VMInsights::MockLog::DEBUG, log[:severity]
                messages = log[:messages]
                assert_equal 2, messages.size, messages.inspect
                assert_equal "VMInsights: ", messages[0]
                assert_equal expected[i], messages[1]
            }
        end

    end # class VMInsights_test

    class MockMetricsEngine
        include ::Test::Unit::Assertions

        def initialize
            @start = 0
            @stop = 0
            @conf = nil
            @mock_data = []
            @run = false
            @thread = nil
        end

        def start(conf, &cb)
            refute_nil conf
            assert_equal @stop, @start
            @conf = conf
            @run = true
            @cb = cb
            @thread = Thread.new {
                thread_body
            }
            @start += 1
        end

        def stop
            @stop += 1
            assert_equal @start, @stop
            @run = false
            @thread.join if @thread
            @thread = nil
        end

        def running?
            @start > @stop
        end

        def check
            assert_operator 1, :<=, @start
            assert_equal @start, @stop
        end

        def add_data(data)
            @mock_data.concat(data)
        end

    private

        def thread_body
            while @run
                (0..@conf.poll_interval).each {
                    return unless @run
                    sleep 1
                }
                unless @mock_data.empty?
                    @cb[@mock_data.shift]
                end
            end
        end

    end

    class MockConf
        def elements
            []
        end
    end

    class MockOutput < Output
        def initialize
            @@instance = self
            @messages = []
        end

        def emit(tag, es, chain)
            es.each { |time, record|
                @messages << [ tag, time, record ]
            }
        end

        def messages
            @messages.clone
        end

        def self.instance
            @@instance
        end
    end

end # module

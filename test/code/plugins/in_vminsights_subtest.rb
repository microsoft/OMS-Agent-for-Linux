# frozen_string_literal: true

require 'test/unit'

require 'tempfile'

#require_relative 'vminsights_test_mockoms.rb'
require_relative 'vminsights_test_mixins.rb'
require_relative 'vminsights_test_mocklog.rb'

module Fluent

    require_relative File.join(SourcePath, 'in_vminsights.rb')

    class VMInsights_test < ::Test::Unit::TestCase

        def initialize(*args)
            super(*args)
            @clean_up = []
        end

        def setup
            @test_start_time = Time.now
            @object_under_test = VMInsights.new
            @mock_tag = "ThE TaG NaMe"
            @mock_log = ::VMInsights::MockLog.new
            @mock_log.ignore_range = ::VMInsights::MockLog::NONE
            @mock_metric_engine = MockMetricsEngine.new

            @conf = {
                :tag => @mock_tag,
                :log => @mock_log,
                :MockMetricsEngine => @mock_metric_engine,
            }

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
            rescue Exception => ex
                puts "#{@mock_log}"
                raise
            end
            @mock_log = nil
        end

        def test_default_parameters
            assert_param :tag, :string
            assert_param :poll_interval, :integer, :default => 60
        end

        def test_default_configure
            @object_under_test.configure @conf

            assert_same @conf, @object_under_test.passed_conf
            router = @object_under_test.router
            assert_not_nil router
            assert_equal [], router.messages
            logs = @mock_log.to_a
            assert logs.size == 0, Proc.new() { @mock_log.to_s }
        end

        def test_metric_engine_upload_start_stop
            @object_under_test.configure @conf
            logs = @mock_log.to_a
            assert logs.size == 0, Proc.new() { @mock_log.to_s }
            @mock_log.ignore_range = ::VMInsights::MockLog::DEBUG_AND_BELOW

            begin
                @object_under_test.start
                sleep(3)
            ensure
                @object_under_test.shutdown
            end

        end

        def test_metric_data_uploaded
            router = @object_under_test.router
            assert_not_nil router
            assert_equal [], router.messages

            @conf[:poll_interval] = 1
            @object_under_test.configure @conf
            logs = @mock_log.to_a
            assert logs.size == 0, Proc.new() { @mock_log.to_s }
            @mock_log.ignore_range = ::VMInsights::MockLog::DEBUG_AND_BELOW

            begin
                expected_data = [ "mock data", "atad kcom" ]
                @object_under_test.start
                (1..3).each { |i| sleep(1) unless @mock_metric_engine.running? }

                count_before = router.messages.size
                @mock_metric_engine.add_data [ expected_data ]
                time_before = Time.now
                (1..3).each { |i| sleep(1) if router.messages.size == count_before }
                time_after = Time.now

                assert_equal (count_before + 1), router.messages.size

                tag, time, wrapper = *(router.messages[count_before])

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
                @mock_log.clear
                @object_under_test.shutdown

                @mock_metric_engine.check
            end
        end

    private

        def assert_param key, *expected
            assert_equal expected, Fluent::Input.params(Fluent::VMInsights)[key]
        end

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

end # module

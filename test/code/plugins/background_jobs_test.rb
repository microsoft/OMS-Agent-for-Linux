require 'test/unit'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/oms_common'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/agent_common'

module OMS

  class BackgroundJobsTest < Test::Unit::TestCase
    class << self
      def startup
      end

      def shutdown
        #no op
      end
    end

    def test_run_job_async_cleanup
      $log = MockLog.new

      OMS::BackgroundJobs.instance.run_job_async(callback=nil) { sleep 10 }
      sleep 0.5
      assert_equal(OMS::BackgroundJobs.instance.proc_cache.size, 1)

      OMS::BackgroundJobs.instance.run_job_async(callback=nil) { sleep 10 }
      sleep 0.5
      assert_equal(OMS::BackgroundJobs.instance.proc_cache.size, 2)
      
      OMS::BackgroundJobs.instance.cleanup
      assert_equal(OMS::BackgroundJobs.instance.proc_cache.size, 0)
    end

    def test_run_job_and_wait_normal
      $log = MockLog.new
      test_returns = [
          nil,
          1,
          "123",
          [],
          [1, 2, 'test'],
      ]
      test_returns.each do |item|
        ret = OMS::BackgroundJobs.instance.run_job_and_wait { item }
        assert_equal(item, ret)
      end
    end


    def test_run_job_and_wait_telemetry
      $log = MockLog.new
      ret1 = [{:source => 'source1', :event => {:message => 'test', :op => 'qos'} }]
      ret = OMS::BackgroundJobs.instance.run_job_and_wait { ret1 }
      assert_equal(ret1, ret)

      ret2 = [{:source => 'source1', :event => 'This is an exception' }]
      ret = OMS::BackgroundJobs.instance.run_job_and_wait { ret2 }
      assert_equal(ret2, ret)
    end

    def test_run_job_and_wait_handle_exception
      $log = MockLog.new
      assert_raises ZeroDivisionError do
        OMS::BackgroundJobs.instance.run_job_and_wait { raise ZeroDivisionError }
      end

      assert_raises RuntimeError do
        OMS::BackgroundJobs.instance.run_job_and_wait { raise RuntimeError.new("Raising Exception") }
      end
    end



  end
end # Module OMS

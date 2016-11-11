require 'fluent/test'
require_relative '../../../source/code/plugins/filter_hdinsight'

class HdinsightFilterTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  def teardown
    super
    Fluent::Engine.stop
  end

  CONFIG = %[]

  def create_driver(conf=CONFIG)
    Fluent::Test::FilterTestDriver.new(Fluent::HdinsightFilter).configure(conf)
  end

  def test_filter
    d = create_driver
    d.instance.command = "echo 'fake_cluster_name'"
    d.run
    record = Hash.new
    emit = d.instance.filter("", "", record)
    assert_equal("fake_cluster_name\n", emit["ClusterName"])
  end
end

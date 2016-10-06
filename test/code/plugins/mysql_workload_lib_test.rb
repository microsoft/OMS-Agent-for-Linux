require 'test/unit'
require 'json'

require_relative '../../../source/code/plugins/mysql_workload_lib'
require_relative 'omstestlib'

class MysqlWorkload_LibTest < Test::Unit::TestCase
  class MysqlMockInterface
    def initialize
      #define different types of input queries to generate mock objects for
      @query_global_status_mock = "SHOW GLOBAL STATUS"
      @query_variables_mock = "SHOW VARIABLES"
      @query_hostname_mock = "SHOW VARIABLES LIKE 'hostname'"
      @query_sizeof_all_dbs_mock = 'select "Total" as "Database", SUM(a.data_length) + SUM(a.index_length) as "Size (Bytes)" from information_schema.schemata b left join information_schema.tables a on b.schema_name = a.table_schema'
      @query_get_databases_mock = 'select b.schema_name as "DatabaseName",COUNT(a.table_name) as "NumberOfTables", SUM(a.data_length) + SUM(a.index_length) as "SizeInBytes" from information_schema.schemata b left join information_schema.tables a on b.schema_name = a.table_schema group by b.schema_name'
      #define different mock objects used with query function
      @global_status_mock_records = [{"Variable_name" => "Threads_connected", "Value" => "1"}, {"Variable_name" => "Aborted_connects", "Value" => "0"}, {"Variable_name" => "Uptime", "Value" => "54"},
        {"Variable_name" => "Key_reads", "Value" => "0"}, {"Variable_name" => "Key_read_requests", "Value" => "0"}, {"Variable_name" => "Queries", "Value" => "1"},
        {"Variable_name" => "Key_writes", "Value" => "27"}, {"Variable_name" => "Key_writes_requests", "Value" => "12"}, {"Variable_name" => "Qcache_hits", "Value" => "0"},
        {"Variable_name" => "Com_select", "Value" => "0"},{"Variable_name" => "Qcache_lowmem_prunes", "Value" => "0"},{"Variable_name" => "Open_tables", "Value" => "0"},
        {"Variable_name" => "Opened_tables", "Value" => "0"},{"Variable_name" => "Table_locks_waited", "Value" => "0"},{"Variable_name" => "Table_locks_immediate", "Value" => "0"},
        {"Variable_name" => "Innodb_buffer_pool_reads", "Value" => "0"},{"Variable_name" => "Innodb_buffer_pool_read_requests", "Value" => "0"},{"Variable_name" => "Innodb_buffer_pool_pages_data", "Value" => "0"},
        {"Variable_name" => "Innodb_buffer_pool_pages_total", "Value" => "0"},{"Variable_name" => "Handler_read_rnd", "Value" => "0"},{"Variable_name" => "Handler_read_first", "Value" => "0"},
        {"Variable_name" => "Handler_read_key", "Value" => "0"},{"Variable_name" => "Handler_read_next", "Value" => "0"},{"Variable_name" => "Handler_read_prev", "Value" => "0"},
        {"Variable_name" => "Handler_read_rnd_next", "Value" => "0"}]

      @variables_mock_records = [{"Variable_name" => "max_connections", "Value" => "100"}, {"Variable_name" => "key_buffer_size", "Value" => "0"},{"Variable_name" => "read_buffer_size", "Value" => "0"},{"Variable_name" => "sort_buffer_size", "Value" => "0"}]

      @sizeof_all_dbs_mock_records = [{"Database" => "Total", "Size (Bytes)" => "571617"}]
      @hostname_mock_records = [{"Variable_name" => "hostname", "Value" => "MockHostname"}]
      @get_databases_mock_records = [{"DatabaseName" =>  "information_schema", "NumberOfTables" => "1", "SizeInBytes" => "1"}]

    end

    def query(input_query)
      puts input_query
      if input_query.eql?(@query_global_status_mock)
        return @global_status_mock_records
      end
      if input_query.eql?(@query_hostname_mock)
        return @hostname_mock_records
      end
      if input_query.eql?(@query_variables_mock)
        return @variables_mock_records
      end
      if input_query.eql?(@query_sizeof_all_dbs_mock)
        return @sizeof_all_dbs_mock_records
      end
      if input_query.eql?(@query_get_databases_mock)
        return @get_databases_mock_records
      end
    end
  end

  def setup
    @mysql_mock_interface = MysqlMockInterface.new
  end

  def teardown
  end

  def test_send_to_oms_all
    host = "MockHostname"
    port = 3306
    username = "root"
    password = nil
    database = nil
    encoding = 'utf8'
    mysql_lib = MysqlWorkload_Lib.new(host, port, username, password, database, encoding, @mysql_mock_interface)
    time = Time.parse('2016-07-21 16:21:19 -0700')
    wrapper = mysql_lib.enumerate(time)
    expected = wrapper.to_json
    oms_mysql_all = "{\"DataType\":\"LINUX_PERF_BLOB\",\"IPName\":\"LogManagement\",\"DataItems\":[{\"Timestamp\":\"2016-07-21T23:21:19.000Z\",\"Host\":\"MockHostname\",\"ObjectName\":\"MySQL Server\",\"InstanceName\":\"MockHostname:3306\",\"Collections\":[{\"CounterName\":\"Number of Connections\",\"Value\":\"1\"},{\"CounterName\":\"Maximum Allowed Connections\",\"Value\":\"100\"},{\"CounterName\":\"Aborted Connections\",\"Value\":\"0\"},{\"CounterName\":\"Uptime\",\"Value\":\"54\"},{\"CounterName\":\"Key Cache Hit Pct\",\"Value\":0.0},{\"CounterName\":\"MySQL Worst Case RAM Usage\",\"Value\":0.0},{\"CounterName\":\"MySQL Server Disk Usage In Bytes\",\"Value\":\"571617\"},{\"CounterName\":\"Slow Query Pct\",\"Value\":\"1\"},{\"CounterName\":\"Key Cache Write Pct\",\"Value\":225.0},{\"CounterName\":\"Query Cache Hit Pct\",\"Value\":0.0},{\"CounterName\":\"Query Cache Low memory Prunes\",\"Value\":0.0},{\"CounterName\":\"Table Cache Hit Pct\",\"Value\":0.0},{\"CounterName\":\"Table Lock Contention Pct\",\"Value\":0.0},{\"CounterName\":\"InnoDB Buffer Pool Hit Percent\",\"Value\":0.0},{\"CounterName\":\"InnoDB Buffer Pool Percent Use\",\"Value\":0.0},{\"CounterName\":\"Full Table Scan Pct\",\"Value\":0.0}]},{\"Timestamp\":\"2016-07-21T23:21:19.000Z\",\"Host\":\"MockHostname\",\"ObjectName\":\"MySQL Database\",\"InstanceName\":\"information_schema\",\"Collections\":[{\"CounterName\":\"NumberOfTables\",\"Value\":\"1\"},{\"CounterName\":\"SizeInBytes\",\"Value\":\"1\"}]}]}"
    assert_equal(oms_mysql_all, expected, "The result of mysql_workload_lib enumerate differs from the expected result")
  end

end
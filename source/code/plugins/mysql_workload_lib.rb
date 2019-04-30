class MysqlWorkload_Lib
  require_relative 'oms_common'

  def initialize(host, port, username, password, database, encoding, mock_interface=nil)
    if mock_interface.nil?
      require 'mysql2'
    end
    @host = host
    @port = port
    @username = username
    @password = password
    @database = database
    @encoding = encoding
    @mock_interface = mock_interface
    @query_global_status = "SHOW GLOBAL STATUS"
    @query_variables = "SHOW VARIABLES"
    # total size of all databases in bytes (ServerDiskUseInBytes)
    @query_sizeof_all_databases = 'select "Total" as "Database", SUM(a.data_length) + SUM(a.index_length) as "Size (Bytes)" from information_schema.schemata b left join information_schema.tables a on b.schema_name = a.table_schema'
    # Execute a query to get a result set like:
    #   +--------------------+--------+-------------------------------+
    #   | Database           | Size (Bytes) |
    #  +--------------------+--------+--------------------------------+
    #   | Total             | 89998192 |
    #   +--------------------+--------+-------------------------------+

    if (@database == nil)

      # Number of tables in each database and the table size in bytes
      @query_get_database = 'select b.schema_name as "DatabaseName",COUNT(a.table_name) as "NumberOfTables", SUM(a.data_length) + SUM(a.index_length) as "SizeInBytes" from information_schema.schemata b left join information_schema.tables a on b.schema_name = a.table_schema group by b.schema_name'
      # Execute a query to get a result set like:
      #   +--------------------+--------+-------------------------------+
      #   | DatabaseName           | NumberOfTables | SizeInBytes |
      #  +--------------------+--------+--------------------------------+
      #   | information_schema |       28 |              8192 |
      #   +--------------------+--------+-------------------------------+
      # Note that Size may be NULL if database has no tables

    else
      # Number of tables in given database and the table size in bytes
      @query_get_database = 'select b.schema_name as "DatabaseName",COUNT(a.table_name) as "NumberOfTables",
                                                                       SUM(a.data_length) + SUM(a.index_length) as "SizeInBytes"
                                                                         from information_schema.schemata b
                                                                         left join information_schema.tables a on b.schema_name = a.table_schema
                                                                         where b.schema_name =\'' + @database + '\' group by b.schema_name'
    end
  end

  def get_connection
    # Opens a connection to mysql server instance
    begin
      return Mysql2::Client.new({
        :host => @host,
        :port => @port,
        :username => @username,
        :password => @password,
        :database => @database,
        :encoding => @encoding,
        :reconnect => true
      })
    rescue Exception => e
      @log.warn("mysql_workload: #{e}")
    end
  end
  
  def close_connection
    # check if close connection was called prior the client connection is created
    if @mysql != nil
      mysql.close
    end
  end
  
  def query(input_query)
    if @mock_interface.nil?
      @mysql ||= get_connection
      begin
        return @mysql.query(input_query, :cast => false, :cache_rows => false)
      rescue Exception => e
        @log.warn("mysql_workload: #{e}")
      end
    else
      return @mock_interface.query(input_query)
    end

  end

  def get_mysql_hostname
    query("SHOW VARIABLES LIKE 'hostname'").each do |row|
      return row.fetch('Value')
    end
  end

  def transform_row(row)
    # creates a new hash table where keys from the input row are replaced with the Variable_name key name, 
    # and the value of the key Variable_name. Case sensitive comparision.
    # Example {VariableName => connectedthreads, Value => 20} will be replaced with {connectedthreads = > 20}
    result = Hash.new()
    result.store(row["Variable_name"], row["Value"] )
    return result
  end

  def get_value (input_array, key_to_find)
    # finds given key in the array of hash tables 
    #and returns it's value, -1 otherwise
    value = -1
    input_array.each do |row|
      if (row.has_key?(key_to_find))
        value = row.fetch(key_to_find)
        break
      end
    end
    return value
  end

  def get_server_database_type
    # default to InnoDB if default_storage_engine not supported
    engine_info_value = "InnoDB"    
    #retrieve engine info from default_storage_engine
    query("show variables like 'default_storage_engine'").each do |row|
    engine_info_value = row.fetch('Value')
    end
    return engine_info_value
  end

  def get_server_database_version
    dbversion_info_value = 0 # default
    #retrieve database version info using innodb_version
    query("show variables like 'version'").each do |row|
    dbversion_info_value = row.fetch('Value')
    end  
    return dbversion_info_value
  end

  def get_server_stats
    global_stats = Array.new
    env_var_stats = Array.new
    #final list of counters that will be sent to oms. Filtered based on mysql spec.
    final_records = Array.new

    # populate all mysql performance and analytical data throw SHOW GLOBAL STATUS or SHOW VARIABLES
    q_global_status = query(@query_global_status)
    q_global_status.each do |row|
      new_row = transform_row(row)
      global_stats.push(new_row)
    end
    q_variables = query(@query_variables)
    q_variables.each do |row|
      new_row = transform_row(row)
      env_var_stats.push(new_row)
    end

    # Add Number of Connections
    num_connections = Hash.new
    num_connections_value = get_value(global_stats, "Threads_connected")
    num_connections.store("Number of Connections", num_connections_value)
    final_records.push(num_connections)

    # Add Maximum Allowed Connections
    max_connections = Hash.new
    max_connections_value = get_value(env_var_stats, "max_connections")
    max_connections.store("Maximum Allowed Connections", max_connections_value)
    final_records.push(max_connections)

    # Add Aborted Connections
    failed_connections = Hash.new
    failedconnections_value = get_value(global_stats, "Aborted_connects")
    failed_connections.store("Aborted Connections", failedconnections_value)
    final_records.push(failed_connections)

    # Add Uptime
    uptime = Hash.new
    uptime_value = get_value(global_stats, "Uptime")
    uptime.store("Uptime", uptime_value)
    final_records.push(uptime)

    # add KeyCacheHitPct
    key_cache_hit_pct = Hash.new
    key_reads = get_value(global_stats,'Key_reads')
    key_read_requests = get_value(global_stats,'Key_read_requests')
    value = 0.0 #initialize
    if key_read_requests.to_f != 0
      value = (key_reads.to_f / key_read_requests.to_f) * 100
    end
    key_cache_hit_pct.store("Key Cache Hit Pct", value.round(2))
    final_records.push(key_cache_hit_pct)

    # add MySQL Worst Case RAM Usage
    server_max_ram= Hash.new
    value = 0.0 #reset
    key_buffer_size = get_value(env_var_stats, 'key_buffer_size')
    read_buffer_size  = get_value(env_var_stats, 'read_buffer_size')
    sort_buffer_size = get_value(env_var_stats, 'sort_buffer_size')
    max_connections = get_value(env_var_stats, 'max_connections')
    value = key_buffer_size.to_f + (read_buffer_size.to_f + sort_buffer_size.to_f)*max_connections.to_f
    server_max_ram.store("MySQL Worst Case RAM Usage", value.round(2))
    final_records.push(server_max_ram)

    #Add MySQL Server Disk Usage In Bytes
    q_size_all_db = query(@query_sizeof_all_databases) # Total size
    q_size_all_db.each do |row|
      s_database = Hash.new()
      s_database.store("MySQL Server Disk Usage In Bytes",row["Size (Bytes)"])
      final_records.push(s_database)
    end

    #add SlowQueryPct
    slow_query_pct = Hash.new
    queries = get_value(global_stats, "Queries")
    if queries == -1
      # On MySQL 5.0 queries is not supported. instead use queries = questions + com_stmt_close + com_stmt_reset + com_stmt_prepare
      # On MySQL 5.1+, just use variable "queries"
      questions = get_value(global_stats, "Questions")
      com_stmt_close = get_value(global_stats, "Com_stmt_close")
      com_stmt_reset = get_Value(global_stats, "Com_stmt_reset")
      com_stmt_prepare = get_value(global_stats, "Com_stmt_prepare")
      queries = questions.to_i + com_stmt_close.to_i + com_stmt_reset.to_i + com_stmt_prepare.to_i
    end
    slow_query_pct.store("Slow Query Pct", queries )
    final_records.push(slow_query_pct)

    #add Key Cache Write Pct
    key_cache_write_pct = Hash.new()
    key_writes = get_value(global_stats,"Key_writes")
    key_writes_requests = get_value(global_stats,"Key_writes_requests")
    value = 0.0
    if(key_writes_requests.to_f != 0)
      value = (key_writes.to_f)/(key_writes_requests.to_f) * 100
    end
    key_cache_write_pct.store("Key Cache Write Pct", value.round(2))
    final_records.push(key_cache_write_pct)

    #add Query CacheHitPct
    query_cache_hit_pct = Hash.new()
    qcache_hits = get_value(global_stats,"Qcache_hits")
    com_select = get_value(global_stats,"Com_select")
    value = 0.0
    if (qcache_hits.to_f + com_select.to_f) != 0
      value = qcache_hits.to_f/(qcache_hits.to_f + com_select.to_f)*100
    end
    query_cache_hit_pct.store("Query Cache Hit Pct", value.round(2))
    final_records.push(query_cache_hit_pct)

    #add Query Cache Low memory Prunes
    query_cache_prunes_pct = Hash.new()
    qcache_prunes = get_value(global_stats,"Qcache_lowmem_prunes")
    value = 0.0
    if queries.to_f != 0
      value = (qcache_prunes.to_f/queries.to_f) * 100
    end
    query_cache_prunes_pct.store("Query Cache Low memory Prunes", value.round(2))
    final_records.push(query_cache_prunes_pct)

    #add TableCacheHitPct
    table_hit_pct = Hash.new()
    open_tables = get_value(global_stats,"Open_tables")
    opened_tables = get_value(global_stats,"Opened_tables")
    value = 0.0
    if opened_tables.to_f != 0
      value = open_tables.to_f/opened_tables.to_f * 100
    end
    table_hit_pct.store("Table Cache Hit Pct", value.round(2))
    final_records.push(table_hit_pct)

    #add TableLockContentionPct
    table_lock_pct = Hash.new()
    table_lock_waited = get_value(global_stats,"Table_locks_waited")
    table_lock_immediate = get_value(global_stats,"Table_locks_immediate")
    value = 0.0
    if (table_lock_waited.to_f + table_lock_immediate.to_f) != 0
      value = table_lock_waited.to_f/(table_lock_waited.to_f + table_lock_immediate.to_f) * 100
    end
    table_lock_pct.store("Table Lock Contention Pct", value.round(2))
    final_records.push(table_lock_pct)

    #add InnoDB Buffer Pool Hit Percent
    idb_hit_pct = Hash.new()
    innodb_buffer_pool_reads = get_value(global_stats,"Innodb_buffer_pool_reads")
    innodb_buffer_pool_read_requests = get_value(global_stats,"Innodb_buffer_pool_read_requests")
    value = 0.0
    if (innodb_buffer_pool_reads.to_f + innodb_buffer_pool_read_requests.to_f) != 0
      value = innodb_buffer_pool_reads.to_f/(innodb_buffer_pool_reads.to_f + innodb_buffer_pool_read_requests.to_f) * 100
    end
    idb_hit_pct.store("InnoDB Buffer Pool Hit Percent", value.round(2))
    final_records.push(idb_hit_pct)

    #add InnoDB Buffer Pool Percent Use
    idb_use_pct = Hash.new()
    innodb_buffer_pool_pages_data = get_value(global_stats,"Innodb_buffer_pool_pages_data")
    innodb_buffer_pool_pages_total = get_value(global_stats,"Innodb_buffer_pool_pages_total")
    value = 0.0
    if( innodb_buffer_pool_pages_total.to_f != 0)
      value = innodb_buffer_pool_pages_data.to_f/innodb_buffer_pool_pages_total.to_f * 100
    end
    idb_use_pct.store("InnoDB Buffer Pool Percent Use", value.round(2) )
    final_records.push(idb_use_pct)

    #add FullTableScanPct
    full_table_pct = Hash.new()
    handler_read_rnd = get_value(global_stats,"Handler_read_rnd")
    handler_read_first = get_value(global_stats,"Handler_read_first")
    handler_read_key = get_value(global_stats,"Handler_read_key")
    handler_read_next = get_value(global_stats,"Handler_read_next")
    handler_read_prev = get_value(global_stats,"Handler_read_prev")
    handler_read_rnd_next = get_value(global_stats,"Handler_read_rnd_next")
    full_scan_reads = handler_read_rnd.to_f + handler_read_rnd_next.to_f
    all_row_access  = handler_read_rnd.to_f + handler_read_first.to_f + handler_read_key.to_f + handler_read_next.to_f + handler_read_prev.to_f + handler_read_rnd_next.to_f
    value = 0.0 #reset
    if all_row_access != 0
      value = full_scan_reads/all_row_access * 100
    end
    full_table_pct.store("Full Table Scan Pct", value.round(2) )
    final_records.push(full_table_pct)

    # add SlaveStatus
    # add SlaveLag
    # add ServerCPU

    return final_records
  end

  # retrieve all databases or given database info of the mysql instance as a hashtable
  def get_server_databases (input_query)
    database_stats = Array.new

    #retrieve engine info from default_storage_engine
    #engine_info_value = get_server_database_type

    #retrieve database version info frm innodb_version
    #dbversion_info_value = get_server_database_version

    #get database table information
    # Example, execute a query to get a result set like:
    #   +--------------------+--------+-------------------------------+
    #   | DatabaseName           | NumberOfTables | SizeInBytes |
    #  +--------------------+--------+--------------------------------+
    #   | information_schema |       28 |              8192 |
    #   +--------------------+--------+-------------------------------+
    stmt = query(input_query)
    stmt.each do |row|
      #   row.store("Engine", engine_info_value)
      #   row.store("Version", dbversion_info_value)
      #   Add SizeAllocated
      #   Add SizeUnits
      #   Add LastBackup
      database_stats.push(row)
    end
    return database_stats
  end

  def get_mysql_instance
    # retrieve mysql instance stats later to be used in heartbeat
    result = Array.new
    row = Hash.new
    host_name = get_mysql_hostname

    row.store("ProductName", "MySQL Server")
    prod_id = host_name + ":" + @port.to_s
    row.store("ProductIdentifyingNumber", prod_id)
    row.store("ProductVendor", "Oracle")
    version_value = get_server_database_version
    row.store("ProductVersion", version_value.to_s)
    q_variables = query(@query_variables)
    server_id = get_value(q_variables,"server_id")
    row.store("SystemID", server_id.to_s)
    compile_os = get_value(q_variables,"version_compile_os")
    row.store("CollectionID", compile_os.to_s)
    row.store("Name", nil)
    socket_info = get_value(q_variables,"socket")
    row.store("SocketFile", socket_info.to_s)
    row.store("Port", @port.to_s)
    data_dir= get_value(q_variables,"datadir")
    row.store("DataDirectory", data_dir.to_s)
    log_error = get_value(q_variables,"log_error")
    row.store("ErrorLogFile", log_error.to_s)
    result.push(row)
    return result
  end

  # Convert data to oms format
  def enumerate (time)
    #final list of counters to send to oms filtered based on the counters supporeted by mysql plugin (per mysql spec)
    final_records = Array.new
    timestamp = OMS::Common.format_time(time)

    # get mysql global stats and variables
    mysqlserver_counters = Array.new
    server_stats = get_server_stats
    server_stats.each do |row|
      row.each {
        |key, value|
        mysql_server_counter = Hash.new
        mysql_server_counter.store("CounterName", key)
        mysql_server_counter.store("Value", value)
        mysqlserver_counters.push(mysql_server_counter)
      }
    end

    host_name = get_mysql_hostname
    # Only one mysql instance is supported
    mysql_instance = Hash.new
    mysql_instance["Timestamp"] = timestamp
    mysql_instance["Host"] = host_name
    mysql_instance["ObjectName"]="MySQL Server"
    mysql_instance_name = host_name + ":" + @port.to_s
    mysql_instance["InstanceName"] = mysql_instance_name
    mysql_instance["Collections"] = mysqlserver_counters
    #add the instance to the list
    final_records.push(mysql_instance)

    #get mysql database tables info
    result_dbs = get_server_databases(@query_get_database)

    result_dbs.each do |row|
      mysql_db_counters = Array.new
      db_instance = Hash.new
      db_instance["Timestamp"] = timestamp
      db_instance["Host"] = host_name
      db_instance["ObjectName"]="MySQL Database"
      db_instance["InstanceName"] = row["DatabaseName"]
      row.delete("DatabaseName") # leave only table name and size columns and remove database name
      row.each {
        |key, value|
        db_counter = Hash.new
        db_counter.store("CounterName", key)
        if value.nil?
          db_counter.store("Value", 0) # if the given database has no tables, set the size to 0 instead of nil
        else
          db_counter.store("Value", value)
        end
        mysql_db_counters.push(db_counter)
      }

      db_instance["Collections"] = mysql_db_counters
      #add the db instance to the list
      final_records.push(db_instance)
    end

    if final_records.length > 0
      wrapper = {
        "DataType"=>"LINUX_PERF_BLOB",
        "IPName"=>"LogManagement",
        "DataItems"=>final_records
      }
      return wrapper
    end
  end
end

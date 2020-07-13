# frozen_string_literal: true

require 'test/unit'

module VMInsights

    require_relative 'vminsights_test_mixins.rb'
    require_relative 'vminsights_test_mocklog.rb'

    require_relative File.join(SourcePath, 'VMInsightsDataCollector.rb')

    class DataCollector_test < Test::Unit::TestCase

        require 'json'

        include FileUtils

        def setup
            @mock_log = ::VMInsights::MockLog.new ::VMInsights::MockLog::NONE
            @mock_log.set_message_hook() { |sev, msgs|
                (::VMInsights::MockLog::DEBUG == sev) &&
                (msgs.size == 1) &&
                (msgs[0].start_with?("get_up_net_devices: No such file or directory @ rb_sysopen "))
            }
            @mock_root_dir = make_temp_directory
            @object_under_test = DataCollector.new @mock_log, @mock_root_dir

            mkdir_p @mock_root_dir, "usr", "bin"
            @lscpu = File.join(@mock_root_dir, LSCPU)
            @lscpu_result = @lscpu + ".result"

            mkdir_p @mock_root_dir, "bin"
            @df = File.join(@mock_root_dir, DF)
            @df_result = @df + ".result"
            @lsblk = File.join(@mock_root_dir, LSBLK)
            @lsblk_result = @lsblk + ".result"
            mock_lsblk

            proc_dir = mkdir_p(@mock_root_dir, "proc")
            @proc_meminfo = File.join(proc_dir, "meminfo")
            @proc_uptime = File.join(proc_dir, "uptime")
            mock_proc_uptime
            proc_net_dir = mkdir_p(proc_dir, "net")
            @mock_netdev = File.join(proc_net_dir, "dev")
            @mock_netroute = File.join(proc_net_dir, "route")
            @mock_virtnet = mkdir_p(@mock_root_dir, "sys", "devices", "virtual", "net")
            make_net_dev
            @oms_agent_basedir = mkdir_p @mock_root_dir, "etc", "opt", "microsoft", "omsagent"
        end

        def teardown
            @oms_agent_basedir = nil
            @mock_netdev = nil
            @mock_netroute = nil
            @mock_netvirt = nil
            @proc_uptime = nil
            @proc_meminfo = nil
            @lsblk_result = nil
            @lsblk = nil
            @lscpu_result = nil
            @lscpu = nil
            @df_result = nil
            @df = nil
            @object_under_test = nil
            recursive_delete @mock_root_dir
            @mock_root_dir = nil

            begin
                assert_equal 0, @mock_log.to_a.size
                @mock_log.check
            rescue Exception
                STDERR.puts @mock_log.to_s
                raise
            end
            @mock_log = nil
        end

        def test_methods_implemented
            assert_kind_of IDataCollector, @object_under_test
            idc = IDataCollector.new.class
            @object_under_test.methods.each { |m|
                refute_equal idc, (@object_under_test.method(m)).owner, "#{@object_under_test.class} doesn't implement #{m}"
            }
        end

        def test_proc_meminfo_missing
            ex = assert_raises(Errno::ENOENT) { ||
                @object_under_test.get_available_memory_kb
            }
            assert ex.message.include?("/proc/meminfo"), ex.inspect
        end

        def test_proc_meminfo_unreadable
            File.new(@proc_meminfo, "w", 0222).close
            begin
                File.open(@proc_meminfo, "r") { |f| }
                omit "#{@proc_meminfo} not R/O"
            rescue Errno::EACCES    # ensure the file has been made unreadable before making test assertions
                assert_raises(Errno::EACCES) { ||
                    @object_under_test.get_available_memory_kb
                }
            end
        end

        def test_proc_meminfo_empty
            File.new(@proc_meminfo, "w").close
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_available_memory_kb
            }
            assert ex.message.include?("Available memory not found"), ex.inspect
        end

        def test_proc_meminfo_garbage
            File.open(@proc_meminfo, WriteASCII) { |f|
                f.puts "gobble", "d", "gook"
            }
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_available_memory_kb
            }
            assert ex.message.include?("Available memory not found"), ex.inspect
        end

        def test_proc_meminfo_all_missing
            File.open(@proc_meminfo, WriteASCII) { |f|
                populate_proc_meminfo f
            }
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_available_memory_kb
            }
            assert ex.message.include?("Available memory not found"), ex.inspect
        end

        def test_proc_meminfo_total_missing
            File.open(@proc_meminfo, WriteASCII) { |f|
                populate_proc_meminfo f, { :metric => MemAvail, :value => 0, :uom => KBuom }
            }
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_available_memory_kb
            }
            assert ex.message.include?("Total memory"), ex.inspect
        end

        def test_proc_meminfo_avail_missing
            File.open(@proc_meminfo, WriteASCII) { |f|
                populate_proc_meminfo f, { :metric => MemTotal, :value => 0, :uom => KBuom }
            }
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_available_memory_kb
            }
            assert ex.message.include?("Available memory"), ex.inspect
        end

        def test_get_available
            expected_total = (__LINE__ << 10) + 17
            expected_available = (__LINE__ << 5) + 42
            unexpected_free = 13
            File.open(@proc_meminfo, WriteASCII) { |f|
                populate_proc_meminfo f,
                                      { :metric => MemTotal, :value => expected_total, :uom => KBuom },
                                      { :metric => MemAvail, :value => expected_available, :uom => KBuom },
                                      { :metric => MemFree, :value => unexpected_free, :uom => KBuom }
            }
            actual_available, actual_total = @object_under_test.get_available_memory_kb
            assert_equal expected_total, actual_total
            assert_equal expected_available, actual_available
        end

        def test_get_available_live
            meminfo_path = "/proc/meminfo"
            omit_unless File.exist?(meminfo_path), "(Linux only)"

            @object_under_test = DataCollector.new @mock_log
            actual_available, actual_total = @object_under_test.get_available_memory_kb
            assert_operator actual_total, :>, 0, "Total memory should be > 0"
            assert_operator actual_available, :<, actual_total, "Available memory should be < Total memory"
        end

        def test_get_cpu_idle_baseline
            check_for_baseline_common
            expected_uptime = 42
            expected_idle = 17
            mock_proc_uptime expected_uptime, expected_idle
            actual = @object_under_test.baseline
            assert_equal expected_uptime, actual[:up]
            assert_equal expected_idle, actual[:idle]
        end

        def test_get_cpu_idle
            check_for_baseline_common
            @object_under_test.baseline
            expected_uptime = 420
            expected_idle = 7
            mock_proc_uptime expected_uptime, expected_idle
            actual_uptime, actual_idle = @object_under_test.get_cpu_idle
            assert_equal expected_uptime, actual_uptime
            assert_equal expected_idle, actual_idle
        end

        def test_get_cpu_idle_fractional
            check_for_baseline_common
            @object_under_test.baseline
            expected_uptime = 0.42
            expected_idle = 0.17
            mock_proc_uptime expected_uptime, expected_idle
            actual_uptime, actual_idle = @object_under_test.get_cpu_idle
            assert_in_delta expected_uptime, actual_uptime, 0.001
            assert_in_delta expected_idle, actual_idle, 0.001
        end

        def test_get_cpu_count
            check_for_lscpu
            expected_count = 12
            make_mock_lscpu expected_count
            @object_under_test.baseline
            assert_equal expected_count, @object_under_test.get_number_of_cpus
            assert_lscpu_exit
        end

        def test_get_cpu_count_no_baseline
            ex = assert_raises(RuntimeError) { ||
                @object_under_test.get_number_of_cpus
            }
            assert ex.message.include?("baseline has not been called"), ex.inspect
        end

        def test_get_cpu_count_no_lscpu
            check_for_lscpu
            @object_under_test.baseline
            ex = assert_raises(IDataCollector::Unavailable) {
                @object_under_test.get_number_of_cpus
            }
            assert ex.message.index(Errno::ENOENT.new.message), ex.inspect
            assert ex.message.index(LSCPU), ex.inspect
        end

        def test_get_cpu_count_never_zero
            check_for_lscpu
            make_mock_lscpu 0
            @object_under_test.baseline
            ex = assert_raises(IDataCollector::Unavailable) {
                @object_under_test.get_number_of_cpus
            }
            assert ex.message.index("No CPUs found"), ex.inspect
            assert_lscpu_exit
        end

        def test_get_cpu_count_garbage
            check_for_lscpu

            File.open(@lscpu, WriteASCII, 0755) { |f|
                f.puts "#!/bin/sh"
                f.puts "echo 'this is a mock comment'"
                f.puts "echo 'this,is,the,mock,header'"
                f.puts "echo -n > #{@lscpu_result}"
                f.puts "exit 0"
            }

            @object_under_test.baseline
            ex = assert_raises(IDataCollector::Unavailable) {
                @object_under_test.get_number_of_cpus
            }
            assert ex.message.index("No CPUs found"), ex.inspect
            assert_lscpu_exit
        end

        def test_get_cpu_count_live
            check_for_lscpu
            expected_count = nil
            IO.popen("sh -c '#{LSCPU} -bp | grep -cv \\#'") { |io|
                data = io.read
                expected_count = data.to_i
            }
            @object_under_test = DataCollector.new @mock_log
            @object_under_test.baseline
            assert_equal expected_count, @object_under_test.get_number_of_cpus
        end

        def test_get_filesystems
            check_for_df
            expected = make_expected_disks 8
            stuff = expected.shuffle
            mock_proc_df stuff
            actual = @object_under_test.get_filesystems
            assert_fs expected, actual
            assert_df_exit
        end

        def test_get_filesystems_no_file_systems
            check_for_df
            expected = []
            mock_proc_df expected
            assert_equal expected, @object_under_test.get_filesystems
            assert_df_exit
        end

        def test_get_cpu_count_no_df
            check_for_df
            ex = assert_raises(IDataCollector::Unavailable) {
                @object_under_test.get_filesystems
            }
            assert ex.message.index(Errno::ENOENT.new.message), ex.inspect
            assert ex.message.index(DF), ex.inspect
        end

        def test_get_filesystems_garbage
            check_for_df
            expected = make_expected_disks 4
            stuff = [
                DfGarbage.new("this is#{__LINE__} some random garbage"),
                DfGarbage.new("/dev/foo#{__LINE__} ext1 42 42 17 2 /"),
                DfGarbage.new("/dev/foo#{__LINE__} ext5 42 42 17 2 /"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4 42 42 2 /"),
                DfGarbage.new("/dev1/foo#{__LINE__} ext4 42 42 17 5 /"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4 0 42 17 3 /shazam"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4 42 42 17 3 shazam"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4 not_int 42 17 3 /shazam"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4 42 42 not_int 3 /shazam"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4 0x42 42 17 4 /shazam"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4 42 42 0x17 4 /shazam"),
                DfGarbage.new("/dev/foo#{__LINE__} text4 42 42 17 4 /shazam"),
                DfGarbage.new("/dev/foo#{__LINE__} ext4b 42 42 17 4 /shazam"),
            ].concat(expected)
            # these look funky, but they should be interpreted as decimal numbers
            stuff << DfGarbage.new("/dev/bar1 ext4 042 42 17 3 /shazam")
            expected << Fs.new("/dev/bar1", "/shazam", 42, 17, 4)
            stuff << DfGarbage.new("/dev/bar2 ext4 42 42 017 2 /shazam")
            expected << Fs.new("/dev/bar2", "/shazam", 42, 17, 4)

            stuff.shuffle!
            mock_proc_df stuff
            actual = @object_under_test.get_filesystems
            assert_fs expected, actual
            assert_df_exit

            begin
                @mock_log.each { |log|
                    assert_equal ::VMInsights::MockLog::DEBUG, log[:severity]
                    messages = log[:messages]
                    assert_kind_of Array, messages
                    assert_equal 1, messages.size
                    msg = messages[0]
                    assert msg.start_with?("get_filesystems: "), msg
                }
            rescue Exception
                STDERR.puts @mock_log.to_s
                raise
            ensure
                @mock_log.clear # no further checking required
            end

        end

        def test_get_filesystems_live
            check_for_df
            expected = {}
            IO.popen("#{DF} --type=ext2 --type=ext3 --type=ext4 --block-size=1 | awk '{print $1,$6,$2}' | tail -n +2", { :in => :close}) { |io|
                data = io.readlines
                data.each { |line|
                    if !line.start_with?("/dev/")
                        puts "Warning: Line doesn't start with #{line}, will be skiped"
                        next
                    end
                    s = line.split(" ")
                    key = s[0].sub(/^\/dev\//, '')
                    omit "#{key} is mounted multiple times. Running in a container" if expected.has_key? key
                    expected[key] = [ s[1], s[2].to_i, false ]
                }
            }
            @object_under_test = DataCollector.new
            @object_under_test.baseline
            actual = @object_under_test.get_filesystems
            assert expected.size == actual.size, Proc.new { "Count mismatch.\n\tExpected: #{expected}\n\tActual: #{actual}" }
            actual.each { |f|
                str = f.inspect
                e = expected[f.device_name]
                assert_not_nil e, "unexpected: #{str}"
                refute e[2], "duplicate fs: #{str}"
                e[2] = true
                assert_equal e[0], f.mount_point, str
                assert_equal e[1], f.size_in_bytes, str
                assert_operator f.free_space_in_bytes, :>=, 0, "Free space should be >= 0"
                assert_operator f.free_space_in_bytes, :<=, f.size_in_bytes, "Free space should be <= total size"
            }
        end

        def test_proc_uptime_unreadable
            File.chmod(0222, @proc_uptime)
            begin
                File.open(@proc_uptime, "r") { |f| }
                omit "#{@proc_uptime} not R/O"
            rescue Errno::EACCES    # ensure the file has been made unreadable before making test assertions
                assert_raises(Errno::EACCES) { ||
                    @object_under_test.get_cpu_idle
                }
            end
        end

        def test_proc_uptime_empty
            File.new(@proc_uptime, "w").close
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_cpu_idle
            }
            assert ex.message.include?("Uptime not found"), ex.inspect
        end

        def test_proc_uptime_garbage
            File.open(@proc_uptime, WriteASCII) { |f|
                f.puts "gobble", "d", "gook"
            }
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_cpu_idle
            }
            assert ex.message.include?("Uptime not found"), ex.inspect
        end

        def test_get_net_stats_no_baseline
            @mock_log.set_message_hook
            ex = assert_raises(RuntimeError) { ||
                @object_under_test.get_net_stats
            }
            assert ex.message.include?("baseline has not been called"), ex.inspect
        end

        def assert_get_net_stats(send_base, rec_base, modulus = (2 ** 64))
            check_for_baseline_common
            expected = {
                "mockb" => { :base_sent => send_base, :base_rec => randint % 1492, :sent => modulus - 24, :rec => 71 },
                "mocka" => { :base_sent => randint % 1776, :base_rec => rec_base, :sent => 17, :rec => modulus - 42 },
            }
            devices_names = expected.keys
            make_routes expected.keys
            make_virtual
            make_net_dev expected.keys.collect { |k| v = expected[k]; { :d => k, :sent => v[:base_sent], :rec => v[:base_rec] } }
            t_before_baseline = Time.now
            @object_under_test.baseline
            t_after_baseline = Time.now

            # create a little separation between samples
            sleep 0.25

            make_net_dev expected.keys.collect { |k| v = expected[k]; { :d => k, :sent => (v[:base_sent] + v[:sent]) % modulus, :rec => (v[:base_rec] + v[:rec]) % modulus } }
            t_before_sample = Time.now
            actual = @object_under_test.get_net_stats
            t_after_sample = Time.now
            actual.each { |v|
                expect = expected.delete v.device
                refute_nil expect, v.device
                assert_equal expect[:sent], v.bytes_sent, v.device
                assert_equal expect[:rec], v.bytes_received, v.device
                range = ( (t_before_sample - t_after_baseline) ..  (t_after_sample - t_before_baseline) )
                assert range.cover?(v.delta_time), Proc.new { "#{v.delta_time} should be in #{range}" }
            }
            assert expected.empty?, expected.to_s

            # with no changes in the net dev data, all interfaces should report 0
            actual = @object_under_test.get_net_stats
            actual.each { |v|
                refute_nil devices_names.delete(v.device), v.device
                assert_equal 0, v.bytes_sent, v.device
                assert_equal 0, v.bytes_received, v.device
            }
            assert devices_names.empty?, devices_names.to_s
        end

        def test_get_net_stats
            @mock_log.set_message_hook
            assert_get_net_stats randint % 1776, randint % 1492
        end

        def test_get_net_stats_interface_up
            @mock_log.set_message_hook
            check_for_baseline_common
            make_virtual
            make_routes [ "mockb" ]
            make_net_dev ["mockb", "mocka", "mockc" ].collect { |k| { :d => k, :sent => randint % 1776, :rec => randint % 1492 } }
            @object_under_test.baseline

            # with no changes in the net dev data, all interfaces should report 0
            # only mocbk should show up because it is "up" (i.e. routes and no activity)
            actual = @object_under_test.get_net_stats

            assert_equal 1, actual.size, actual.inspect
            actual = actual[0]
            assert_equal "mockb", actual.device
            assert_equal 0, actual.bytes_sent
            assert_equal 0, actual.bytes_received

            # bring mocka "up" and it should be included
            device_names = ["mocka", "mockb"]
            make_routes device_names

            actual = @object_under_test.get_net_stats
            actual.each { |v|
                refute_nil device_names.delete(v.device), v.device
                assert_equal 0, v.bytes_sent, v.device
                assert_equal 0, v.bytes_received, v.device
            }
            assert device_names.empty?, device_names.to_s
        end

        def test_get_net_stats_interface_down
            @mock_log.set_message_hook
            check_for_baseline_common
            make_virtual
            device_names = ["mocka", "mockb", "mockc"]
            make_routes device_names
            original =  device_names.collect { |k| { :d => k, :sent => randint % 1776, :rec => randint % 1492 } }
            make_net_dev original
            @object_under_test.baseline

            # Add some traffic
            make_net_dev original.collect { |d| d = d.clone; h = d[:d].hash.abs | 0xFFF0; d[:sent] = d[:sent] + 1 + h; d[:rec] = d[:rec] + 2 + h; d }
            # turn mockb "down" by removing its routes
            make_routes ["mocka", "mockc"]

            actual = @object_under_test.get_net_stats
            actual.each { |v|
                refute_nil device_names.delete(v.device), v.device
                h = v.device.hash.abs | 0xFFF0
                assert_equal (1 + h), v.bytes_sent, v.device
                assert_equal (2 + h), v.bytes_received, v.device
            }
            assert device_names.empty?, device_names.to_s

            # get another sample with no changes and only the devices that are "up" should be included
            device_names = ["mocka", "mockc"]

            actual = @object_under_test.get_net_stats
            actual.each { |v|
                refute_nil device_names.delete(v.device), v.device
                assert_equal 0, v.bytes_sent, v.device
                assert_equal 0, v.bytes_received, v.device
            }
            assert device_names.empty?, device_names.to_s
        end

        def test_get_net_stats_rollover
            @mock_log.set_message_hook
            make_mock_lscpu 1, false
            assert_get_net_stats (2 ** 64) - 1, (2 ** 32) - 1, (2 ** 64)
        end

        def test_get_net_stats_rollover32
            @mock_log.set_message_hook
            make_mock_lscpu 1, true
            assert_get_net_stats (2 ** 16) - 1, (2 ** 32) - 1, (2 ** 32)
        end

        def test_get_net_stats_live
            @mock_log.set_message_hook
            netdev_path = "/proc/net/dev"
            virtnet_path = "/sys/devices/virtual/net"
            netroute_path = "/proc/net/route"
            [ netdev_path, virtnet_path, netroute_path ].each { |p| omit_unless File.exist?(p), "(Linux only)" }

            net_stats_before = get_live_net_stats
            omit "all network devices are virtual; possibly being run inside a container" if net_stats_before.empty?
            @object_under_test = DataCollector.new
            @object_under_test.baseline
            make_some_network_traffic
            actual = @object_under_test.get_net_stats
            net_stats_after = get_live_net_stats
            omit "network state changed #{net_stats_before.keys} --> #{net_stats_after.keys}" unless net_stats_before.keys.sort! == net_stats_after.keys.sort!
            delta = net_stats_after.merge(net_stats_before) { |key, after, before|
                        after.merge(before) { |dir, after, before|
                            # assumption 64-bit counter
                            ((2 ** 64) + after - before) % (2 ** 64)
                        }
                    }
            actual.each { |v|
                reference = delta.delete v.device
                refute_nil reference, v.device
                assert_operator v.bytes_sent, :>=, 0, v.to_s
                assert_operator v.bytes_sent, :<=, reference[:sent], v.to_s
                assert_operator v.bytes_received, :>=, 0, v.to_s
                assert_operator v.bytes_received, :<=, reference[:received], v.to_s
            }
            assert delta.empty?, "Missing device data: #{delta}"
        end

        def test_get_disk_stats_no_baseline
            ex = assert_raises(RuntimeError) { ||
                @object_under_test.get_disk_stats("/dev/sda10")
            }
            assert ex.message.include?("baseline has not been called"), ex.inspect
        end

        def test_get_disk_stats_live
            lsblk_path = "/bin/lsblk"
            omit_unless File.exist?(lsblk_path), "(Linux only)"
            sector_size = {}
            IO.popen("sh -c '#{LSBLK} -sndoNAME,LOG-SEC | tr -s \" \"'") { |io|
                while (line = io.gets)
                    data = line.split(" ")
                    sector_size[data[0]] = data[1].to_i
                end
            }

            @object_under_test = DataCollector.new @mock_log
            live_disk_data_before = get_live_disk_data sector_size
            omit_unless sector_size.size == live_disk_data_before.size, "inconsistent disk data (before)"
            time_before_baseline = Time.now
            @object_under_test.baseline
            time_after_baseline = Time.now

            # cause some disk activity and a short delay
            File.open(make_temp_file(make_temp_directory), "wb+") { |f|
                pattern = "xyzz" * 1024
                t = Time.now + 0.75
                f.puts pattern while Time.now < t
                f.rewind
                while f.gets do end
            }

            actual = { }
            time_before_get = Time.now
            sector_size.each_key { |k| actual[k] = @object_under_test.get_disk_stats(k) }
            time_after_get = Time.now

            live_disk_data_after = get_live_disk_data sector_size
            omit_unless live_disk_data_before.size == live_disk_data_after.size, "inconsistent disk data (before)"

            # compare
            min_delta_time = time_before_get - time_after_baseline
            max_delta_time = time_after_get - time_before_baseline

            sector_size.each_key { |dev|
                a = actual[dev]
                refute_nil a, "#{dev} not found"
                before = live_disk_data_before[dev]
                after = live_disk_data_after[dev]
                assert_in_range min_delta_time, max_delta_time, a.delta_time, dev
                assert_in_range 0, (after[:reads] - before[:reads]), a.reads, dev
                assert_in_range 0, (after[:bytes_read] - before[:bytes_read]), a.bytes_read, dev
                assert_in_range 0, (after[:writes] - before[:writes]), a.writes, dev
                assert_in_range 0, (after[:bytes_written] - before[:bytes_written]), a.bytes_written, dev
            }

        end

        def test_get_disk_stats_rollover32
            make_mock_lscpu 1, true
            assert_get_disk_stats (2**32) - 1, (2**16) - 1, (2 ** 32)
        end

        def test_get_disk_stats_rollover
            make_mock_lscpu 1, false
            assert_get_disk_stats (2**64) - 1, (2**32) - 1, (2 ** 64)
        end

        def test_get_disk_stats_new_disk
            check_for_baseline_common
            @object_under_test.baseline

            mock_lsblk "new_disk 17"
            make_mock_disk_stats [
                                    { :name => "new_disk", :reads => 1, :read_sectors => 2, :writes => 3, :write_sectors => 4 }
                                 ]

            time_before_1st_get = Time.now
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_disk_stats("new_disk")
            }
            time_after_1st_get = Time.now
            assert ex.message.include?("no previous data for new_disk"), ex.inspect
            # should have polled lsblk to get sector size
            assert_lsblk_exit

            sleep 1
            make_mock_disk_stats [
                                    { :name => "new_disk", :reads => 11, :read_sectors => 22, :writes => 33, :write_sectors => 44 }
                                 ]
            time_before_2nd_get = Time.now
            actual = @object_under_test.get_disk_stats("new_disk")
            time_after_2nd_get = Time.now

            assert_lsblk_not_run

            assert_equal "new_disk", actual.device
            assert_equal 10, actual.reads
            assert_equal (17 * 20), actual.bytes_read
            assert_equal 30, actual.writes
            assert_equal (17 * 40), actual.bytes_written
            assert_in_range (time_before_2nd_get - time_after_1st_get),
                            (time_after_2nd_get - time_before_1st_get),
                            actual.delta_time

        end

        def test_get_disk_stats_lsblk_not_found
            File.delete @lsblk
            make_mock_disk_stats [
                                    { :name => "sda10", :reads => 1, :read_sectors => 2, :writes => 3, :write_sectors => 4 }
                                 ]
            @object_under_test.baseline

            sleep 1
            time_before_1st_get = Time.now
            ex = assert_raises(IDataCollector::Unavailable) { ||
                @object_under_test.get_disk_stats("sda10")
            }
            time_after_1st_get = Time.now
            assert ex.message.include?("no previous data for sda10"), ex.inspect

            sleep 1
            make_mock_disk_stats [
                                    { :name => "sda10", :reads => 11, :read_sectors => 22, :writes => 33, :write_sectors => 44 }
                                 ]
            time_before_2nd_get = Time.now
            actual = @object_under_test.get_disk_stats("sda10")
            time_after_2nd_get = Time.now

            assert_equal "sda10", actual.device
            assert_equal 10, actual.reads
            assert_nil actual.bytes_read
            assert_equal 30, actual.writes
            assert_nil actual.bytes_written

            assert_in_range (time_before_2nd_get - time_after_1st_get),
                            (time_after_2nd_get - time_before_1st_get),
                            actual.delta_time

            begin
                @mock_log.each { |log|
                    assert_equal ::VMInsights::MockLog::DEBUG, log[:severity]
                    messages = log[:messages]
                    assert_kind_of Array, messages
                    assert_equal 1, messages.size
                    msg = messages[0]
                    assert_equal "get_sector_sizes: No such file or directory - #{@mock_root_dir}/bin/lsblk", msg
                }
            rescue Exception
                STDERR.puts @mock_log.to_s
                raise
            ensure
                @mock_log.clear # no further checking required
            end
        end

    private

        def assert_get_disk_stats(big, small, modulus)
            check_for_baseline_common
            # create 4 mock disks, one for each of the 4 data to test.
            # use a distinct, prime, sector size for each
            disks = {

                "reads" => {
                    :sector_size => 3 * 512,
                    :base   => { :reads =>   big, :read_sectors => small, :writes => small, :write_sectors => small },
                    :deltas => [
                                    { :reads => small, :read_sectors => small, :writes => small, :write_sectors => small },
                                    { :reads =>   big, :read_sectors =>     1, :writes =>     2, :write_sectors =>     3 }
                    ]
                },

                "bytes_read" => {
                    :sector_size => 5 * 512,
                    :base   => { :reads => small, :read_sectors =>   big, :writes => small, :write_sectors => small },
                    :deltas => [
                                    { :reads => small, :read_sectors => small, :writes => small, :write_sectors => small },
                                    { :reads =>     1, :read_sectors =>   big, :writes =>     2, :write_sectors =>     3 }
                    ]
                },

                "writes" => {
                    :sector_size => 7 * 512,
                    :base   => { :reads => small, :read_sectors => small, :writes =>   big, :write_sectors => small },
                    :deltas => [
                                    { :reads => small, :read_sectors => small, :writes => small, :write_sectors => small },
                                    { :reads =>     1, :read_sectors =>     2, :writes =>   big, :write_sectors =>     3 }
                    ]
                },

                "bytes_written" => {
                    :sector_size => 11 * 512,
                    :base   => { :reads => small, :read_sectors => small, :writes => small, :write_sectors =>   big },
                    :deltas => [
                                    { :reads => small, :read_sectors => small, :writes => small, :write_sectors => small },
                                    { :reads =>     1, :read_sectors =>     2, :writes =>     3, :write_sectors =>   big }
                    ]
                },

            }

            mock_lsblk_devs = ""
            disks.each do |k, v|
                mock_lsblk_devs += "#{k} "
                mock_lsblk_devs += v[:sector_size].to_s
                mock_lsblk_devs += "\n"
            end
            mock_lsblk mock_lsblk_devs
            # make_mock_disk_stats using big and small for initial values
            current = disks.map { |k, v|
                                    baseline = v[:base].clone
                                    baseline[:name] = k
                                    baseline
                                }
            make_mock_disk_stats current

            @object_under_test.baseline

            expected = { }
            (0 ... 2).each { |i|
                sleep 1
                current.each_index { |j|
                    c = current[j]
                    dev_name = c[:name]
                    dev = disks[dev_name]
                    delta = dev[:deltas][i]
                    c.merge!(delta) { |k, old_val, delta| (old_val + delta) % modulus }
                    expected["#{dev_name}"] = {
                        "reads" => delta[:reads],
                        "bytes_read" => delta[:read_sectors] * dev[:sector_size],
                        "writes" => delta[:writes],
                        "bytes_written" => delta[:write_sectors] * dev[:sector_size],
                    }
                }
                make_mock_disk_stats current

                expected.each_pair { |dev_name, expected_values|
                    actual = @object_under_test.get_disk_stats dev_name
                    [ "reads", "bytes_read", "writes", "bytes_written" ].each { |value_key|
                        assert_equal expected_values[value_key], actual.method(value_key)[], "#{i}: #{dev_name}: #{value_key}"
                    }
                }
            }
        end

        def make_routes(devs)
            File.open(@mock_netroute, WriteASCII) { |f|
                f.puts "iiii\tddddddd\tggggg\tfffff\trc\tu\tm\tmk\tmtu\tw\tI" # header line
                format = "%s\t%08X\t%08X\t1\t0\t0\t0\tabcdef01\t0\t0\t1"
                devs.each { |d|
                    f.puts format % [ d, randint | 0xffffffff, 0 ]
                    f.puts format % [ d, 0 , randint | 0xffffffff ]
                }
            }
        end

        def make_virtual
            [ "lo", "vpm" ].each { |d| mkdir_p @mock_virtnet, d }
        end

        def make_net_dev(expected = [])
            others = [
                { :d => "lo", :sent => 2400, :rec => 7100 }, #loopback (virtual)
                { :d => "vpm", :sent => 1700, :rec => 4200 }, #VPM (virtual?)
                { :d => "xyzzy17", :sent => 4321, :rec => 1234 }, #interface without routes
            ]
            File.open(@mock_netdev, WriteASCII) { |f|
                f.puts "Inter-|   Receive                                                |  Transmit"
                f.puts "face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed"
                (others + expected).shuffle!.each { |v|
                    f.puts ("%6s: %7d   113 213 313 413 513 613 713 %7d 813 913 1013 1113 1213 1313 1413" % [ v[:d], v[:rec], v[:sent] ])
                }
            }
        end


        def randint
            rand 0x10000000000000000
        end

        def mkdir_p(base, *n)
            result = base
            n.each { |i|
                result = File.join(result, i)
                Dir.mkdir result unless Dir.exist? result
            }
            result
        end

        def guid(a = randint, b = randint, c = randint, d = randint, e = randint)
            sprintf "%08x-%04x-%04x-%04x-%012x", a % 0xfffffff, b % 0xffff, c % 0xffff, d % 0xffff, e % 0xffffffffffff
        end

        def populate_proc_meminfo(f, *tuples)
            f.puts ProcMemSamplePart0
            f.puts ProcMemSamplePart1
            tuples.each { |t|
                f.puts "#{t[:metric]}:     #{t[:value]}#{t[:uom]}"
            }
            f.puts ProcMemSamplePart0
        end

        def mock_proc_uptime(expected_uptime = 0, expected_idle = 0)
            File.open(@proc_uptime, WriteASCII) { |f|
                populate_proc_uptime f, expected_uptime, expected_idle
            }
        end

        def check_for_lscpu
            check_for LSCPU
        end

        def check_for_df
            check_for DF
        end

        def check_for_lsblk
            check_for LSBLK
        end

        def check_for_baseline_common
            check_for_lsblk
        end

        def check_for(p)
            omit_unless File.executable?(p), "system doesn't have #{p}"
        end

        def get_live_net_stats
            # assumptions:
            #   interesting devices are eth[0-9]+
            #   all devices are online
            #   no devices will go up or down during the test
            result = {}
            sys_devices_virtual_net = File.join("/", "sys", "devices", "virtual", "net")
            File.open("/proc/net/dev", ReadASCII) { |f|
                while line = f.gets
                    if line =~ /^ *eth[0-9]*:/
                        line.lstrip!
                        tokens = line.split(/[: ] */)
                        next if Dir.exist? File.join(sys_devices_virtual_net, tokens[0])
                        result[tokens[0]] = { :received => tokens[1].to_i, :sent => tokens[9].to_i }
                    end
                end
            }
            result
        end

        def get_live_disk_data(devices)
            result = { }

            File.open("/proc/diskstats", ReadASCII) { |f|
                while line = f.gets
                    data = line.split(" ")
                    dev = data[2]
                    next unless devices.key? dev
                    result[dev] = {
                        :reads => data[1 + 2].to_i,
                        :bytes_read => data[3 + 2].to_i * devices[dev],
                        :time_reading => data[4 + 2].to_i,
                        :writes => data[5 + 2].to_i,
                        :bytes_written => data[7 + 2].to_i * devices[dev],
                        :time_writing => data[8 + 2].to_i,
                    }
                end
            }

            result
        end

        def make_some_network_traffic
            system("ping", "-w", "2", "microsoft.com", :in => :close, :err => File::NULL, :out => File::NULL )
        end

        def make_mock_lscpu(expected_count = 1, is_32_bit=false)
            File.open(@lscpu, WriteASCII, 0755) { |f|
                f.puts "#!/bin/sh"
                f.puts "if [ -z \"$*\" ]; then"
                f.puts "    echo 'Architecture:          x86_64'"
                f.puts "    echo 'CPU op-mode(s):        32-bit" + (is_32_bit ? "" : ", 64-bit") + "'"
                f.puts "    echo 'Byte Order:            Little Endian'"
                f.puts "    echo 'CPU(s):                1'"
                f.puts "    echo 'On-line CPU(s) list:   0'"
                f.puts "    echo 'Thread(s) per core:    1'"
                f.puts "    echo 'Core(s) per socket:    1'"
                f.puts "    echo 'Socket(s):             1'"
                f.puts "    echo 'NUMA node(s):          1'"
                f.puts "    echo 'Vendor ID:             GenuineIntel'"
                f.puts "    echo 'CPU family:            6'"
                f.puts "    echo 'Model:                 62'"
                f.puts "    echo 'Model name:            Intel(R) Xeon(R) CPU E5-2650L v2 @ 1.70GHz'"
                f.puts "    echo 'Stepping:              4'"
                f.puts "    echo 'CPU MHz:               1687.736'"
                f.puts "    echo 'BogoMIPS:              3375.47'"
                f.puts "    echo 'Hypervisor vendor:     Microsoft'"
                f.puts "    echo 'Virtualization type:   full'"
                f.puts "    echo 'L1d cache:             32K'"
                f.puts "    echo 'L1i cache:             32K'"
                f.puts "    echo 'L2 cache:              256K'"
                f.puts "    echo 'L3 cache:              25600K'"
                f.puts "    echo 'NUMA node0 CPU(s):     0'"
                f.puts "    echo 'Flags:                 fpu vme'"
                f.puts "    exit 0"
                f.puts "fi"
                f.puts "if [ \"$1\" != '-p' ]; then echo bad args: $* > #{@lscpu_result} ; exit 1; fi"
                f.puts "echo '# this is a mock comment'"
                f.puts "echo '# this,is,the,mock,header'"
                (0...expected_count).each { |i|
                    f.puts "echo '#{i},1,2,3,#{i}'"
                }
                f.puts "echo -n > #{@lscpu_result}"
                f.puts "exit 0"
            }
        end


        ProcMemSamplePart1 = [      # deliberately mixing up the order
            "Buffers:          278492 kB",
            "Cached:           512852 kB",
        ]

        ProcMemSamplePart0 = [
            "SwapCached:            0 kB",
            "Active:           737116 kB",
            "Inactive:         337128 kB",
            "Active(anon):     287424 kB",
            "Inactive(anon):      224 kB",
            "Active(file):     449692 kB",
            "Inactive(file):   336904 kB",
            "Unevictable:        5408 kB",
            "Mlocked:            5408 kB",
            "SwapTotal:             0 kB",
            "SwapFree:              0 kB",
            "Dirty:               120 kB",
            "Writeback:             0 kB",
            "AnonPages:        261452 kB",
            "Mapped:            58692 kB",
            "Shmem:               712 kB",
            "Slab:             240772 kB",
            "SReclaimable:     185780 kB",
            "SUnreclaim:        54992 kB",
        ]

        ProcMemSamplePart2 = [
            "KernelStack:        3916 kB",
            "PageTables:         6236 kB",
            "NFS_Unstable:          0 kB",
            "Bounce:                0 kB",
            "WritebackTmp:          0 kB",
            "CommitLimit:      857996 kB",
            "Committed_AS:     882784 kB",
            "VmallocTotal:   34359738367 kB",
            "VmallocUsed:           0 kB",
            "VmallocChunk:          0 kB",
            "HardwareCorrupted:     0 kB",
            "AnonHugePages:     88064 kB",
            "ShmemHugePages:        0 kB",
            "ShmemPmdMapped:        0 kB",
            "CmaTotal:              0 kB",
            "CmaFree:               0 kB",
            "HugePages_Total:       0",
            "HugePages_Free:        0",
            "HugePages_Rsvd:        0",
            "HugePages_Surp:        0",
            "Hugepagesize:       2048 kB",
            "Hugetlb:               0 kB",
            "DirectMap4k:      155584 kB",
            "DirectMap2M:     1679360 kB",
            "DirectMap1G:           0 kB",
        ]

        MemTotal = "MemTotal"
        MemFree = "MemFree"
        MemAvail = "MemAvailable"

        Bytesuom = ""
        KBuom = " kB"
        MBuom = " mB"

        WriteASCII = "w:ASCII-8BIT"
        ReadASCII = "r:ASCII-8BIT"

        def populate_proc_uptime(f, uptime, idle)
            f.puts " #{uptime} \t #{idle}\t"
        end

        def assert_in_range(expected_low, expected_high, actual, msg=nil)
            assert_range (expected_low .. expected_high), actual, msg
        end

        def assert_range(range, actual, msg=nil)
            assert range.cover?(actual), Proc.new {
                msg = msg.nil? ? "" : "#{msg}: "
                "#{msg}#{actual} should be in #{range}"
            }
        end

        def assert_lscpu_exit
            unless File.zero?(@lscpu_result)
                flunk IO.read @lscpu_result
            end
        end

        def assert_fs(expected, actual)
            assert_equal expected.size, actual.size, actual.join("\n")
            expected = expected.sort
            actual = actual.sort
            (0 .. expected.size).each { |i|
                if expected[i].nil?
                    assert_nil actual[i], "#{i}: not nil: #{actual[i]}"
                else
                    assert expected[i].equivilent?(actual[i]), "#{i}: #{expected[i]}\n#{actual[i]}"
                end
            }
        end

        def assert_df_exit
            unless File.zero?(@df_result)
                flunk IO.read @df_result
            end
        end

        def assert_lsblk_exit
            unless File.zero?(@lsblk_result)
                flunk IO.read @lsblk_result
            end
            File.delete(@lsblk_result)
        end

        def assert_lsblk_not_run
            if File.exist?(@lsblk_result)
                flunk IO.read @lsblk_result
            end
        end

        class Fs
            def initialize(dev, mp, size, free, type=(Random.rand(3) + 2))
                @dev = dev
                @mp = mp
                @size = size
                @free = free
                @type = type
            end

            def to_s
                "%-10s %-15s %15d %15d" % [ @dev, @mp, @size, @free ]
            end

            def equivilent?(actual)
                @dev == '/dev/' + actual.device_name &&
                @mp == actual.mount_point &&
                @size == actual.size_in_bytes &&
                @free == actual.free_space_in_bytes
            end

            def <=>(o)
                r = @dev <=> o.dev; return r unless r.zero?
                r = @mp <=> o.mp; return r unless r.zero?
                r = @size <=> o.size; return r unless r.zero?
                @free <=> o.dev
            end

            def make_df
                "%-*s ext%d %*d %*d %*d %*d %-*s" % [
                    Random.rand(20), @dev,
                    @type,
                    Random.rand(20), @size,
                    Random.rand(20), 42,
                    Random.rand(20), @free,
                    Random.rand(20), 42,
                    Random.rand(20), @mp
                ]
            end

            attr_reader :dev, :mp, :size, :free
        end

        class DfGarbage < String
            def initialize(s)
                super(s)
            end

            alias_method :make_df, :to_s
        end

        def make_expected_disks(n)
            seed = Random.rand(26)
            Array.new(n) { |i|
                i = (i + seed) % 26
                dev = "/dev/harddisk%s" % ('a' ... 'z').to_a[i]
                mount = "/xyzzy/mnt#{i}"
                size = Random.rand(1024 * 1024 * 1024 * 1024)
                free = Random.rand(size + 1)
                Fs.new(dev, mount, size, free)
            }
        end

        def mock_proc_df(a)
            # df --block-size=1 -T
            # Filesystem     Type        1B-blocks        Used    Available Use% Mounted on
            File.open(@df, WriteASCII, 0755) { |f|
                f.puts "#!/bin/sh"
                f.puts "if [ \"$*\" != \"--block-size=1 -T\" ]; then echo bad args: $* > #{@df_result} ; exit 1; fi"
                f.puts "echo 'Filesystem     Type        1B-blocks        Used    Available Use% Mounted on'"
                a.each { |d| f.puts "echo '#{d.make_df}'" }
                f.puts "echo -n > #{@df_result}"
                f.puts "exit 0"
            }
        end

        def mock_lsblk(devs = nil)
            File.open(@lsblk, WriteASCII, 0755) { |f|
                marker="__MARK#{randint}__"
                f.puts "#!/bin/sh"
                f.puts "if [ \"$1\" != '-sd' -o \"$2\" != '-oNAME,LOG-SEC' ]; then echo bad args: $* > #{@lsblk_result} ; exit 1; fi"
                f.puts "cat <<#{marker}"
                f.puts "NAME LOG-SEC"
                f.puts "junk-d1    17"
                f.puts devs unless devs.nil?
                f.puts "junk-d2    42"
                f.puts "#{marker}"
                f.puts "echo -n > #{@lsblk_result}"
                f.puts "exit 0"
            }
        end

        def make_mock_disk_stats(devs)
            devs.each { |dev|
                mkdir_p(@mock_root_dir, "sys", "class", "block", dev[:name])
                dev_path = File.join(@mock_root_dir, "sys", "class", "block", dev[:name])
                path = File.join(dev_path, "stat")
                File.open(path, WriteASCII) { |f|
                    f.puts "%8d %8d %8d %8d %8d %8d %8d %8d %8d %8d %8d" % [
                        dev[:reads],
                        randint % 25,
                        dev[:read_sectors],
                        randint % 2500,
                        dev[:writes],
                        randint % 25,
                        dev[:write_sectors],
                        randint % 2500,
                        randint % 7,
                        randint % 1500,
                        randint % 1500
                    ]
                }
            }
        end

        LSCPU = File.join(File::SEPARATOR + "usr", "bin", "lscpu");
        DF = File.join(File::SEPARATOR + "bin", "df");
        LSBLK = File.join(File::SEPARATOR + "bin", "lsblk");
    end # class DataCollector_test

end #module

require 'fluent/test'
require_relative '../../../source/code/plugins/oms_configuration'
require_relative '../../../source/code/plugins/oms_diag_lib'
require_relative '../../../source/code/plugins/out_oms_diag'

class OutOMSDiagPluginTest < Test::Unit::TestCase
    class Fluent::OutputOMSDiag

        attr_reader :mock_data

        def initialize
            super
            @mock_data = {}
        end

        def handle_record(ipname, record)
            @mock_data[ipname] = record
        end
    end

    class OMS::Configuration
        class << self
            def configurationLoaded=(configLoaded)
                @@ConfigurationLoaded = configLoaded
            end
        end
    end

    def setup
        Fluent::Test.setup
        # mock the configuration to be loaded
        OMS::Configuration.configurationLoaded = true
    end

    def teardown
    end

    def create_spurious_dataitem(log, ipname)
        dataitem = create_valid_dataitem(log, ipname)
        # only delete logmessage or time as ipname is set to default if absent
        # thereby having no ipname before sending to write is non spurious
        if rand(100) % 2 == 0
            dataitem.delete(OMS::Diag::DI_KEY_LOGMESSAGE)
        else
            dataitem.delete(OMS::Diag::DI_KEY_TIME)
        end
    end

    def create_valid_dataitem(log, ipname)
        dataitem = Hash.new
        dataitem[OMS::Diag::DI_KEY_LOGMESSAGE] = log
        dataitem[OMS::Diag::DI_KEY_IPNAME] = ipname
        dataitem[OMS::Diag::DI_KEY_TIME] = OMS::Diag.GetCurrentFormattedTimeForDiagLogs()
        dataitem
    end

    # basically validate the aggregation process
    def test_batch_data
        # initialize plugin and buffer
        plugin = Fluent::OutputOMSDiag.new
        buffer = Fluent::MemoryBufferChunk.new('memory')

        # setting some testing parameters
        test_ipname_01 = 'TestIPName01'
        test_ipname_02 = 'TestIPName02'
        di_count_default_ipname = 5
        di_count_test_ipname_01 = 3
        di_count_test_ipname_02 = 4

        # create dataitems that need to be part of chunk
        dataitems = []
        (1..di_count_default_ipname).each do
            dataitems << create_valid_dataitem('Some Message', OMS::Diag::DEFAULT_IPNAME)
            dataitems << create_spurious_dataitem('Some Message', OMS::Diag::DEFAULT_IPNAME)
        end
        (1..di_count_test_ipname_01).each do
            dataitems << create_valid_dataitem('Some Message', test_ipname_01)
            dataitems << create_spurious_dataitem('Some Message', test_ipname_01)
        end
        (1..di_count_test_ipname_02).each do
            dataitems << create_valid_dataitem('Some Message', test_ipname_02)
            dataitems << create_spurious_dataitem('Some Message', test_ipname_02)
        end

        # populate the buffer chunk with dataitems
        chunk = ''
        for x in dataitems
            chunk << x.to_msgpack
        end
        buffer << chunk

        assert_nothing_raised(RuntimeError, "Failed to send some data") do
            # call plugin write with this chunk
            plugin.write(buffer)

            assert_equal(true, plugin.mock_data.key?(OMS::Diag::DEFAULT_IPNAME),
                         "#{OMS::Diag::DEFAULT_IPNAME} IPName should be present in mock data")
            assert_equal(di_count_default_ipname,
                         plugin.mock_data[OMS::Diag::DEFAULT_IPNAME][OMS::Diag::RECORD_DATAITEMS].size,
                         "There should be #{di_count_default_ipname} dataitems for ipname #{OMS::Diag::DEFAULT_IPNAME}")

            assert_equal(true, plugin.mock_data.key?(test_ipname_01),
                         "#{test_ipname_01} IPName should be present in mock data")
            assert_equal(di_count_test_ipname_01,
                         plugin.mock_data[test_ipname_01][OMS::Diag::RECORD_DATAITEMS].size,
                         "There should be #{di_count_test_ipname_01} dataitems for ipname #{test_ipname_01}")

            assert_equal(true, plugin.mock_data.key?(test_ipname_02),
                         "#{test_ipname_02} IPName should be present in mock data")
            assert_equal(di_count_test_ipname_02,
                         plugin.mock_data[test_ipname_02][OMS::Diag::RECORD_DATAITEMS].size,
                         "There should be #{di_count_test_ipname_02} dataitems for ipname #{test_ipname_02}")
        end

    end
end

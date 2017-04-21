# This file is utilized for testing oms_diag.rb as part of oms_diag_test.rb

require_relative '../../../source/code/plugins/oms_diag_lib'
module Fluent
    class DiagTest < Input
        Fluent::Plugin.register_input('diagTest', self)

        def initialize
            require_relative '../../../source/code/plugins/oms_diag_lib'
        end

        LOG_TYPE_01 = 'LogSimple'
        LOG_TYPE_02 = 'LogWithIPName'
        LOG_TYPE_03 = 'LogWithoutIPNameAndWithProperties'
        LOG_TYPE_04 = "LogWithoutIPNameAndWithPropertiesOverridingMandatory"

        LOG_STR_01  = 'Logging with string 01'
        LOG_STR_02  = 'Logging with string 02'
        LOG_STR_03  = 'Logging with string 03'
        LOG_STR_04  = 'Logging with string 04'

        LOG_IPNAME  = 'DiagnosticsTest'
        LOG_PROPERTIES_FOR_03 = {'abc'=>'def', 'xyz'=>'uvw'}
        LOG_PROPERTIES_FOR_04 = {
                                OMS::Diag::DI_KEY_LOGMESSAGE => 'Spurious message',
                                OMS::Diag::DI_KEY_IPNAME => 'Spurious IPName'
                                }

        config_param :diag_log_type, :string, :defult => LOG_TYPE_01

        attr_accessor :diag_log_type

        def configure(conf)
            super
        end

        def start
            if @diag_log_type == LOG_TYPE_01
                OMS::Diag.LogDiag(LOG_STR_01)
            elsif @diag_log_type == LOG_TYPE_02
                OMS::Diag.LogDiag(LOG_STR_02, nil, LOG_IPNAME)
            elsif @diag_log_type == LOG_TYPE_03
                OMS::Diag.LogDiag(LOG_STR_03, nil, nil, LOG_PROPERTIES_FOR_03)
            elsif @diag_log_type == LOG_TYPE_04
                OMS::Diag.LogDiag(LOG_STR_04, nil, nil, LOG_PROPERTIES_FOR_04)
            end
        end

        def shutdown
        end

    end # class DiagTest
end # module Fluent

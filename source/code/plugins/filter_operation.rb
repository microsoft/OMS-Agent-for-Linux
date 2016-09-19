# Copyright (c) Microsoft Corporation.  All rights reserved.
module Fluent
  class OperationFilter < Filter

    Plugin.register_filter('filter_operation', self)

    require_relative 'operation_lib'

    def start
      super
      @operation_lib = OperationModule::Operation.new(OperationModule::RuntimeError.new)
    end
			
    def filter(tag, time, record)
      records = @operation_lib.filter_and_wrap(tag, record, time)
      # only return non empty records
      if !records.empty?
        return records
      end
    end

  end
end


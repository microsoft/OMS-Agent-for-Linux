module OMS
  require_relative 'omslog'

  class FlattenJson
    # select element(s) of a Json object.
    # split the element if it's an array
    # flatten the inner Json objects to single layer
    def select_split_flatten(time, record, select, es)
      begin
        data = eval(select)
      rescue => e
        Log.error_once("Invalid select: #{select} #{e}");
      end

      if data.instance_of?(Array)
        data.each { |d| es.add(time, flatten(d)) }
      else
        es.add(time, flatten(data))
      end
    end

    def flatten(data, parent_prefix=nil)
      res = {}

      if !data.nil?
        data.each_with_index do |elem, i|
          if elem.is_a?(Array)
            k, v = elem
          else
            k, v = i, elem
          end

          key = parent_prefix ? "#{parent_prefix}_#{k}" : k

          if v.is_a? Enumerable
            res.merge!(flatten(v, key))
          else
            res[key] = v
          end
        end
      end

      return res
    end
  end
end

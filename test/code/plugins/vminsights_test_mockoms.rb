# faking out the dependency on OMS::Common
# frozen_string_literal: true

module Fluent

    class Input

        def initialize
            @router = MockRouter.new
        end

        @@params = Hash.new() { |hash, key|
            hash[key] = {}
        }

        def self.config_param name, *args, &block
            raise ArgumentError unless name
            raise ArgumentError unless Symbol === name
            @@params[self][name] = args
        end

        def configure(conf)
            @passed_conf = conf
            working_conf = conf.dup
            @@params[self.class].each_pair { |key, value|
                v = if working_conf.has_key? key
                        working_conf.delete key
                    elsif value.size < 2
                        raise Exception, "#{key} not set in conf"
                    else
                        hash = value[1]
                        raise Exception.new("not hash #{key}: #{value}") unless (Hash === hash)
                        hash[:default] || (raise Exception, "#{key}: no default")
                    end
                instance_name = "@#{key}"
                instance_variable_set instance_name, v
            }
            working_conf.each_pair { |key, value|
                instance_name = "@#{key}"
                instance_variable_set instance_name, value
            }
        end

        def start
        end

        def shutdown
        end

        attr_reader :router

        #for testing
        attr_reader :passed_conf

        def self.params clazz
            @@params[clazz]
        end

    private

        class MockRouter
            def initialize
                @rules = {}
                @messages = []
            end

            def add_rule(tag, receiver)
                @rules[tag] = receiver
            end

            def emit(tag, time, message)
                messages << [tag, time, message]
            end

            attr_reader :rules, :messages

        end # class MockRouter

    end # class Input

    class Plugin
        def self.register_input name, clazz
        end
    end # class Plugin

    class Engine
        def self.now
            Time.now
        end
    end # class Engine

    class ConfigError < RuntimeError
    end

end #module Fluent

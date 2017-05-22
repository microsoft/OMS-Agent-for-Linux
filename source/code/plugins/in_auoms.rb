#
# Fluentd
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

require 'fileutils'
require 'socket'

require 'cool.io'
require 'yajl'

require 'fluent/input'
require 'fluent/event'

module Fluent
  class AuOMSInput < Input
    Plugin.register_input('auoms', self)

    config_param :blocking_timeout, :time, default: 0.5

    desc 'Tag of the output events.'
    config_param :tag, :string, default: nil
    desc 'The path to your Unix Domain Socket.'
    config_param :path, :string, default: nil
    desc 'The backlog of Unix Domain Socket.'
    config_param :backlog, :integer, default: nil

    def start
      @loop = Coolio::Loop.new
      @lsock = listen
      @loop.attach(@lsock)
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @loop.watchers.each {|w| w.detach }
      @loop.stop
      @lsock.close
      @thread.join
    end

    def listen
      if File.exist?(@path)
        File.unlink(@path)
      end
      FileUtils.mkdir_p File.dirname(@path)
      @log.info "Listening auoms socket at #{@path}"
      s = Coolio::UNIXServer.new(@path, Handler, @log, method(:on_message))
      s.listen(@backlog) unless @backlog.nil?
      s
    end

    def run
      @loop.run(@blocking_timeout)
    rescue
      @log.error "unexpected error", error: $!.to_s
      @log.error_backtrace
    end

    private

    # message Message {
    #   1: float time
    #   2: object record
    # }
    def on_message(msg)
      return if !msg.is_a?(Array)
      return if msg.size < 2
      time = msg[0]
      time = Engine.now if time.to_i == 0
      record = msg[1]
      return if record.nil?

      router.emit(@tag, time, record)
    end

    class Handler < Coolio::Socket
      def initialize(io, log, on_message)
        super(io)
        @on_message = on_message
        @log = log
      end

      def on_connect
        @log.trace { "Connected auoms socket object_id=#{self.object_id}" }
      end

      def on_read(data)
        first = data[0]
        if first == '{' || first == '['
          m = method(:on_read_json)
          @y = Yajl::Parser.new
          @y.on_parse_complete = @on_message
        else
          m = method(:on_read_msgpack)
          @u = Fluent::Engine.msgpack_factory.unpacker
        end

        (class << self; self; end).module_eval do
          define_method(:on_read, m)
        end
        m.call(data)
      end

      def on_read_json(data)
        @y << data
      rescue
        @log.error "Unexpected error", error: $!.to_s, data: data
        @log.error_backtrace
        close
      end

      def on_read_msgpack(data)
        @u.feed_each(data, &@on_message)
      rescue
        @log.error "Unexpected error", error: $!.to_s
        @log.error_backtrace
        close
      end

      def on_close
        @log.trace { "Closed auoms socket object_id=#{self.object_id}" }
      end
    end
  end
end

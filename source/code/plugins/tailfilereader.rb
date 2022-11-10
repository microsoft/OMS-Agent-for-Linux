require 'optparse'
require 'logger'

module Tailscript

  class NewTail  
    def initialize(paths)
      @paths = paths
      @tails = {}
      @pos_file = $options[:pos_file] 
      @read_from_head = $options[:read_from_head]
      @pf = nil
      @pf_file = nil
      level = 'info'

      level = $options[:log_level] if $options.has_key?(:log_level)
      # trace is not supported, let fallback to debug
      level = 'debug' if level == 'trace'

      @log = Logger.new(STDERR)
      @log.level = level
      @log.formatter = proc do |severity, time, progname, msg|
        "#{severity} #{msg}\n"
      end
      @log.info "sudo tail plugin in agent configuration is provisioned to tail files from the following paths: #{paths}, log_level=#{level}"
    end

    attr_reader :paths

    def file_exists(path)
      if File.exist?(path)
        @log.info "File path #{path} exists. Trying to tail."
        return path
      else
        @log.info "#{path} does not exist or not accessable. Cannot tail the file. Skipping."
        return nil
      end
    end

    def expand_paths()
      arr_paths = @paths.split(',').map {|path| path.strip }
      date = Time.now
      expanded_paths = []
      arr_paths.each { |path|
        path = date.strftime(path)
        if path.include?('*')
          Dir.glob(path).select { |p|
          begin
            is_file = !File.directory?(p)
            if File.readable?(p) && is_file
              @log.info "Following tail of #{p}"
              expanded_paths << p
            elsif !File.readable?(p)
              @log.info "#{p} is excluded since it's unreadable or doesn't have proper permissions."
            else
              @log.warn "#{p} is a directory and thus cannot be tailed"
            end
          rescue Errno::ENOENT
            @log.warn("#{p} is missing after refreshing file list")
          end
          }
        else
          file = file_exists(path)
          if !file.nil?
            if File.readable?(path) && !File.directory?(path)
              expanded_paths << file 
            elsif !File.readable?(path)
              @log.info "#{path} is excluded since it's unreadable or doesn't have proper permissions."
            else
              @log.warn "#{path} is a directory and thus cannot be tailed"
            end
          end
        end
      }
      return expanded_paths
    end

    def start
      paths = expand_paths()
      start_watchers(paths) unless paths.empty?
    end

    def shutdown
      @pf_file.close if @pf_file
    end

    def setup_watcher(path, pe)
      tw = TailWatcher.new(path, pe, @read_from_head, @log, &method(:receive_lines))
      tw.on_notify
      tw
    end

    def start_watchers(paths)
      if @pos_file
        @pf_file = File.open(@pos_file, File::RDWR|File::CREAT)
        @pf_file.sync = true
        @pf = PositionFile.parse(@pf_file, @log)
      end

      paths.each { |path|
        pe = nil
        if @pf
          pe = @pf[path]    #pe is FilePositionEntry instance
          if @read_from_head && pe.read_inode.zero?
            begin
              pe.update(File::Stat.new(path).ino, 0)
            rescue Errno::ENOENT
              @log.info "#{path} not found. Continuing without tailing it."
            end
          end
        end
        
        @tails[path] = setup_watcher(path, pe)
      }
    end

    def receive_lines(lines, tail_watcher)
      unless lines.empty?
        puts lines 
      end
      return true
    end

    class TailWatcher
      def initialize(path, pe, read_from_head, log, &receive_lines)
        @path = path
        @pe = pe || MemoryPositionEntry.new
        @read_from_head = read_from_head
        @log = log
        @receive_lines = receive_lines
        @rotate_handler = RotateHandler.new(path, log, &method(:on_rotate))
        @io_handler = nil
      end

      attr_reader :path

      def wrap_receive_lines(lines)
        @receive_lines.call(lines, self)
      end

      def on_notify
        @rotate_handler.on_notify if @rotate_handler
        return unless @io_handler
        @io_handler.on_notify
      end

      def on_rotate(io)
        if io
          # first time
          stat = io.stat
          fsize = stat.size
          inode = stat.ino

          last_inode = @pe.read_inode
          if @read_from_head
            pos = 0
            @pe.update(inode, pos)
          elsif inode == last_inode 
            # rotated file has the same inode number as the pos_file.
            # seek to the saved position
            pos = @pe.read_pos 
          elsif last_inode != 0
            # read data from the head of the rotated file.
            pos = 0
            @pe.update(inode, pos)
          else
            # this is the first MemoryPositionEntry for the first time fluentd started.
            # seeks to the end of the file to know where to start tailing
            pos = fsize
            @pe.update(inode, pos)
          end
          io.seek(pos)
          @io_handler = IOHandler.new(io, @pe, @log, &method(:wrap_receive_lines))
        else
          @io_handler = NullIOHandler.new
        end
      end

      class IOHandler
        def initialize(io, pe, log, &receive_lines)
          @log = log
          @io = io
          @pe = pe
          @log = log
          @read_lines_limit = 1000 
          @receive_lines = receive_lines
          @buffer = ''.force_encoding('ASCII-8BIT')
          @iobuf = ''.force_encoding('ASCII-8BIT')
          @lines = []
          @SEPARATOR = -"\n"
        end

        attr_reader :io

        def on_notify
          @log.debug "Seeking to read file - #{@io.path} from #{@io.pos} position and file size is #{@io.stat.size}"
          begin
            read_more = false
            if @lines.empty?
              begin
                while true
                  if @buffer.empty?
                    @io.readpartial(2048, @buffer)
                  else
                    @buffer << @io.readpartial(2048, @iobuf)
                  end
                  while idx = @buffer.index(@SEPARATOR)
                    @lines << @buffer.slice!(0, idx + 1)
                  end
                  if @lines.size >= @read_lines_limit
                    # not to use too much memory in case the file is very large
                    read_more = true
                    break
                  end
                end
              rescue EOFError
              end
            end

            unless @lines.empty?
              if @receive_lines.call(@lines)
                @pe.update_pos(@io.pos - @buffer.bytesize)
                @lines.clear
              else
                read_more = false
              end
            end
          end while read_more

        rescue
          @log.error "#{$!.to_s}"
          close
        end

        def close
          @io.close unless @io.closed?
        end
      end

      class NullIOHandler
        def initialize
        end

        def io
        end

        def on_notify
        end

        def close
        end
      end

      class RotateHandler
        def initialize(path, log, &on_rotate)
          @path = path
          @inode = nil
          @fsize = -1  # first
          @on_rotate = on_rotate
          @log = log
        end

        def on_notify
          begin
            stat = File.stat(@path) #returns a File::Stat object for the file named @path
            inode = stat.ino
            fsize = stat.size
          rescue Errno::ENOENT
            # moved or deleted
            inode = nil
            fsize = 0
          end

          begin
            if @inode != inode || fsize < @fsize
              # rotated or truncated
              begin
                io = File.open(@path)
              rescue Errno::ENOENT
              end
              @on_rotate.call(io)
            end
            @inode = inode
            @fsize = fsize
          end

        rescue
          @log.error "#{$!.to_s}"
        end
      end
    end


    class PositionFile
      UNWATCHED_POSITION = 0xffffffffffffffff

      def initialize(file, file_mutex, map, last_pos)
        @file = file
        @file_mutex = file_mutex
        @map = map
        @last_pos = last_pos
      end

      def [](path)
        if m = @map[path]
          return m
        end

        @file_mutex.synchronize {
          @file.pos = @last_pos
          @file.write "#{path}\t0000000000000000\t0000000000000000\n"
          seek = @last_pos + path.bytesize + 1
          @last_pos = @file.pos
          @map[path] = FilePositionEntry.new(@file, @file_mutex, seek, 0, 0)
        }
      end

      def self.parse(file, log)
        @log = log
        compact(file)

        file_mutex = Mutex.new
        map = {}
        file.pos = 0
        file.each_line {|line|
          m = /^([^\t]+)\t([0-9a-fA-F]+)\t([0-9a-fA-F]+)/.match(line)
          unless m
            @log.warn "Unparsable line in pos_file: #{line}. Skipping."
            next
          end
          path = m[1]
          pos = m[2].to_i(16)
          ino = m[3].to_i(16)
          seek = file.pos - line.bytesize + path.bytesize + 1
          map[path] = FilePositionEntry.new(file, file_mutex, seek, pos, ino)
        }
        new(file, file_mutex, map, file.pos)
      end

      # Clean up unwatched file entries
      def self.compact(file)
        file.pos = 0
        existent_entries = file.each_line.map { |line|
          m = /^([^\t]+)\t([0-9a-fA-F]+)\t([0-9a-fA-F]+)/.match(line)
          unless m
            @log.warn "Unparsable line in pos_file: #{line}. Skipping."
            next
          end
          path = m[1]
          pos = m[2].to_i(16)
          ino = m[3].to_i(16)
          # 32bit inode converted to 64bit at this phase
          pos == UNWATCHED_POSITION ? nil : ("%s\t%016x\t%016x\n" % [path, pos, ino])
        }.compact

        file.pos = 0
        file.truncate(0)
        file.write(existent_entries.join)
      end
    end

    # pos               inode
    # ffffffffffffffff\tffffffffffffffff\n
    class FilePositionEntry
      POS_SIZE = 16
      INO_OFFSET = 17
      INO_SIZE = 16
      LN_OFFSET = 33
      SIZE = 34

      def initialize(file, file_mutex, seek, pos, inode)
        @file = file
        @file_mutex = file_mutex
        @seek = seek
        @pos = pos
        @inode = inode
      end

      def update(ino, pos)
        @file_mutex.synchronize {
          @file.pos = @seek
          @file.write "%016x\t%016x" % [pos, ino]
        }
        @pos = pos
        @inode = ino
      end

      def update_pos(pos)
        @file_mutex.synchronize {
          @file.pos = @seek
          @file.write "%016x" % pos
        }
        @pos = pos
      end

      def read_inode
        @inode
      end

      def read_pos
        @pos
      end
    end

    class MemoryPositionEntry
      def initialize
        @pos = 0
        @inode = 0
      end

      def update(ino, pos)
        @inode = ino
        @pos = pos
      end

      def update_pos(pos)
        @pos = pos
      end

      def read_pos
        @pos
      end

      def read_inode
        @inode
      end
    end
  end
end

if __FILE__ == $0
  $options = {:read_from_head => false}
  OptionParser.new do |opts|
    opts.on("-p", "--posfile [POSFILE]") do |p|
      $options[:pos_file] = p
    end
    opts.on("-h", "--[no-]readfromhead") do |h|
      $options[:read_from_head] = h 
    end
    opts.on("--log_level [LOG_LEVEL]") do |level|
      $options[:log_level] = level
    end
  end.parse!
  begin
    a = Tailscript::NewTail.new(ARGV[0])
    a.start
    a.shutdown
  rescue => e
    log = Logger.new(STDERR)
    log.formatter = proc do |severity, time, progname, msg| 
      "#{severity} #{msg}\n"
    end
    log.error "Tailfilereader crashed due to an unexpected exit --- #{e.message}  #{e.backtrace.inspect}"
  end

end


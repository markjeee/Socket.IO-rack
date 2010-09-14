module Palmade::SocketIoRack
  # at the moment, only works with Redis
  class Persistence
    autoload :BaseStore, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/persistence/base_store')
    autoload :RedisStore, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/persistence/redis_store')
    autoload :MemoryStore, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/persistence/memory_store')

    DEFAULT_OPTIONS = {
      :cache_expiry => 60 * 60, # default: 1 hr
      :cache_key => 'Socket.IO-rack/persistence'.freeze,
      :store => :memory,
      :sidbits => 128
    }

    attr_reader :options

    def initialize(options = { })
      @options = DEFAULT_OPTIONS.merge(options)
    end

    # Create a new session
    def create_session(session_id = nil)
      sess_opts = {
        :cache_key => @options[:cache_key],
        :cache_expiry => @options[:cache_expiry],
        :sidbits => @options[:sidbits],
      }

      Palmade::SocketIoRack::Session.new(store, session_id, sess_opts)
    end

    # Extend an existing one, or create a new one, if not found
    def resume_session(session_id)
      if store.session_exists?(session_id)
        create_session(session_id)
      else
        nil
      end
    end

    def reset
      store.reset
    end

    def close
      store.close
    end

    def store
      if defined?(@store) && !@store.nil?
        @store
      else
        case @options[:store]
        when String
          klass = self.class.const_get(@options[:store])
        when Class
          klass = @options[:store]
        when :redis
          klass = RedisStore
        when :memory
          klass = MemoryStore
        else
          raise SessionError, "Unknown session store: #{@options[:store]}"
        end

        @store = klass.new(@options)
      end
    end
  end
end

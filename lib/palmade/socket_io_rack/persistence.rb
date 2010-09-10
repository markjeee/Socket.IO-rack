module Palmade::SocketIoRack
  # at the moment, only works with Redis
  class Persistence
    DEFAULT_OPTIONS = {
      :cache_expiry => 60 * 60, # default: 1 hr
      :cache_key => 'Socket.IO-rack/persistence'.freeze,
      :host => '127.0.0.1'.freeze,
      :port => '6379'.freeze,
      :db => 0,
      :sidbits => 128
    }

    CInbox = "inbox".freeze
    COutbox = "outbox".freeze

    attr_reader :options

    def initialize(options = { })
      @options = DEFAULT_OPTIONS.merge(options)
    end

    # Create a new session
    def create_session(session_id = nil)
      sess_opts = {
        :cache_key => @options[:cache_key],
        :cache_expiry => @options[:cache_expiry],
        :sidbits => @options[:sidbits]
      }

      Palmade::SocketIoRack::Session.new(self, session_id, sess_opts)
    end

    # Extend an existing one, or create a new one, if not found
    def resume_session(session_id)
      session_cache_key = "#{@options[:cache_key]}/#{session_id}".freeze

      if rcache.exists(session_cache_key)
        create_session(session_id)
      else
        nil
      end
    end

    def rcache
      if defined?(@rcache) && !@rcache.nil?
        @rcache
      else
        ropts = { }
        [ :host, :port, :db, :logger ].each { |o| ropts[o] = @options[o] }
        @rcache = Redis.new(ropts)
      end
    end

    def reset
      close
      rcache
    end

    def close
      rcache.quit
      @rcache = nil
    end
  end
end

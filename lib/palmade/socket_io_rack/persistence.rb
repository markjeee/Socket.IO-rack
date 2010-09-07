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

    def initialize(options = { })
      @options = DEFAULT_OPTIONS.merge(options)
    end

    # Create a new session
    def create_session
      sess_opts = {
        :cache_key => @options[:cache_key],
        :cache_expiry => @options[:cache_expiry],
        :sidbits => @options[:sidbis]
      }

      Palmade::SocketIoRack::Session.new(self, nil, sess_opts).persist
    end

    # Extend an existing one, or create a new one, if not found
    def resume_session(session_id)
      Palmade::SocketIoRack::Session.find(session_id)
    end

    def rcache
      if defined?(@rcache) && !@rcache.nil?
        @rcache
      else
        ropts = { }
        [ :host, :port, :db ].each { |o| ropts[o] = @options[o] }
        @rcache = Redis.new(ropts)
      end
    end

    def reset
      close
      @rcache = nil
      rcache
    end

    def close
      rcache.close
    end
  end
end

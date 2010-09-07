module Palmade::SocketIoRack
  class Session
    DEFAULT_OPTIONS = {
      :sidbits => 128,
      :cache_key => 'Socket.IO-rack/persistence'.freeze
    }

    # TODO: Implement finding of existing session
    def self.find(sess_id)
      nil
    end

    attr_reader :session_id

    def initialize(persistence, sess_id = nil, options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @persistence = persistence

      if sess_id.nil?
        new!
        @session_id = generate_sid
      else
        not_new!
        @session_id = sess_id
      end
    end

    def new?; @new; end
    def new!; @new = true; end
    def not_new!; @new = false; end

    # TODO: !!! Implement the functionalities below

    # create the initial keys, and set their expiry
    def persist(tm = nil)
      self
    end

    # re-extend their expiry from this time on
    def renew(tm = nil)
      self
    end

    # HGET: Get hash value
    def [](k)
    end

    # HSET: Set hash value
    def []=(k,v)
    end

    # HKEYS
    def keys
    end

    # HVALS
    def values
    end

    # HLEN
    def size
    end
    alias :length :size

    # HEXISTS
    def include?(k)
    end
    alias :exists? :include?

    # For reference sake:
    #
    # * inbox queue are for messages *from* the clients, or web browser
    #   clients, etc.
    # * outbox queue are for messages *for* the clinets, or web
    #   browser clients, etc; that are generated internally.

    # save to inbox
    def push_inbox(*msgs)
    end

    # get msg from inbox queue
    def pop_inbox(*msgs)
    end

    # save to outbox
    def push_outbox(*msgs)
    end

    # get msg from outbox queue
    def pop_outbox(*msgs)
    end

    protected

    def rcache; @persistence.rcache; end

    # session, points to a HASH value in Redis store
    def session_cache_key
      @session_cache_key ||= "#{@options[:cache_key]}/#{session_id}".freeze
    end

    # outbox: points to a LIST (LPOP to get entries, RPUSH to enqueue)
    def outbox_cache_key
      @outbox_cache_key ||= "#{session_cache_key}/outbox".freeze
    end

    # inbox: points to a LIST (LPOP to get entries, RPUSH to enqueue)
    def inbox_cache_key
      @inbox_cache_key ||= "#{session_cache_key}/inbox".freeze
    end

    # Stolen from Rack::Abstract::Id
    def generate_sid
      "%0#{@options[:sidbits] / 4}x" %
        rand(2**@options[:sidbits] - 1)
    end
  end
end

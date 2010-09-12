module Palmade::SocketIoRack
  class Session
    class SessionError < StandardError; end

    DEFAULT_OPTIONS = {
      :sidbits => 128,
      :cache_key => 'Socket.IO-rack/persistence'.freeze,
      :cache_expiry => 60 * 60, # default: 1 hr
    }

    attr_reader :options
    attr_reader :session_id

    def initialize(persistence, sess_id = nil, options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @persistence = persistence
      @dropped = false

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
    def dropped?; @dropped; end

    # create the initial keys, and set their expiry
    def persist!
      case
      when new?
        rcache.pipelined do
          rcache.hset(session_cache_key, '_created', Time.now.to_s)

          rcache.expire(session_cache_key, @options[:cache_expiry])
          rcache.expire(inbox_cache_key, @options[:cache_expiry])
          rcache.expire(outbox_cache_key, @options[:cache_expiry])
        end

        not_new!
      when dropped?
        raise SessionError, "Can't persist, this has been dropped already."
      else
        raise SessionError, "Can't persist, already existed. Try renew! instead."
      end

      self
    end
    alias :persist :persist!

    def drop!
      case
      when new?
        raise SessionError, "Can't drop, this hasn't been persisted yet."
      when dropped?
        raise SessionError, "Already dropped. No need to drop again."
      else
        @dropped = true

        rcache.pipelined do
          rcache.del(session_cache_key)
          rcache.del(inbox_cache_key)
          rcache.del(outbox_cache_key)
        end

        self
      end
    end
    alias :drop :drop!

    # re-extend their expiry from this time on
    def renew!
      case
      when new?
        raise SessionError, "Can't renew, this hasn't been persisted yet. Try persist! instead."
      when dropped?
        raise SessionError, "Can't renew, this has been dropped."
      else
        rcache.pipelined do
          rcache.expire(session_cache_key, @options[:cache_expiry])
          rcache.expire(inbox_cache_key, @options[:cache_expiry])
          rcache.expire(outbox_cache_key, @options[:cache_expiry])
        end
      end

      self
    end
    alias :renew :renew!

    # HSET: Set hash value
    def []=(k,v)
      case
      when new?
        raise SessionError, "You need to persist this first."
      when dropped?
        raise SessionError, "Alread dropped."
      else
        rcache.hset(session_cache_key, k.to_s, v)
      end
    end

    # HGET: Get hash value
    def [](k)
      rcache.hget(session_cache_key, k.to_s)
    end

    # HKEYS
    def keys
      rcache.hkeys(session_cache_key)
    end

    # HVALS
    def values
      rcache.hvals(session_cache_key)
    end

    # HLEN
    def size
      rcache.hlen(session_cache_key)
    end
    alias :length :size

    # HEXISTS
    def include?(k)
      rcache.hexists(session_cache_key, k.to_s)
    end
    alias :exists? :include?

    # HDEL
    def delete(k)
      rcache.hdel(session_cache_key, k.to_s)
    end

    # For reference sake:
    #
    # * inbox queue are for messages *from* the clients, or web browser
    #   clients, etc.
    # * outbox queue are for messages *for* the clients, or web
    #   browser clients, etc; that are generated internally.

    # save to inbox
    def push_inbox(*msgs)
      pushed_count = 0

      case
      when new?
        raise SessionError, "Can't push to a non-persisted session"
      when dropped?
        raise SessionError, "Can't push to a dropped session"
      else
        msgs = msgs.to_a.flatten
        rcache.pipelined do
          msgs.each do |m|
            rcache.rpush(inbox_cache_key, m)
            pushed_count += 1
          end
        end
      end

      pushed_count
    end

    # get msg from inbox queue
    def pop_inbox
      rcache.lpop(inbox_cache_key)
    end

    def inbox_size
      rcache.llen(inbox_cache_key)
    end

    # save to outbox
    def push_outbox(*msgs)
      pushed_count = 0

      case
      when new?
        raise SessionError, "Can't push to a non-persisted session"
      when dropped?
        raise SessionError, "Can't push to a dropped session"
      else
        msgs = msgs.to_a.flatten
        rcache.pipelined do
          msgs.each do |m|
            rcache.rpush(outbox_cache_key, m)
            pushed_count += 1
          end
        end
      end

      pushed_count
    end

    # get msg from outbox queue
    def pop_outbox
      rcache.lpop(outbox_cache_key)
    end

    def outbox_size
      rcache.llen(outbox_cache_key)
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

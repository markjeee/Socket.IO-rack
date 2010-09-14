module Palmade::SocketIoRack
  class Session
    class SessionError < StandardError; end

    DEFAULT_OPTIONS = {
      :sidbits => 128
    }

    attr_reader :options
    attr_reader :session_id
    attr_reader :store

    def initialize(store, sess_id = nil, options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @dropped = false

      if sess_id.nil?
        new!
        @session_id = generate_sid
      else
        not_new!
        @session_id = sess_id
      end

      @store = store
    end

    def new?; @new; end
    def new!; @new = true; end
    def not_new!; @new = false; end
    def dropped?; @dropped; end

    # create the initial keys, and set their expiry
    def persist!
      case
      when new?
        @store.persist!(self)
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
        @store.drop!(self)
      end

      self
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
        @store.renew!(self)
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
        @store.set(self, k, v)
      end
    end

    # HGET: Get hash value
    def [](k)
      @store.get(self, k)
    end

    # HKEYS
    def keys
      @store.keys(self)
    end

    # HVALS
    def values
      @store.values(self)
    end

    # HLEN
    def size
      @store.size(self)
    end
    alias :length :size

    # HEXISTS
    def include?(k)
      @store.include?(self, k)
    end
    alias :exists? :include?

    # HDEL
    def delete(k)
      @store.delete(self, k)
    end

    # For reference sake:
    #
    # * inbox queue are for messages *from* the clients, or web browser
    #   clients, etc.
    # * outbox queue are for messages *for* the clients, or web
    #   browser clients, etc; that are generated internally.

    # save to inbox
    def push_inbox(*msgs)
      case
      when new?
        raise SessionError, "Can't push to a non-persisted session"
      when dropped?
        raise SessionError, "Can't push to a dropped session"
      else
        @store.push_inbox(self, *msgs)
      end
    end

    # get msg from inbox queue
    def pop_inbox
      @store.pop_inbox(self)
    end

    def inbox_size
      @store.inbox_size(self)
    end

    # save to outbox
    def push_outbox(*msgs)
      case
      when new?
        raise SessionError, "Can't push to a non-persisted session"
      when dropped?
        raise SessionError, "Can't push to a dropped session"
      else
        @store.push_outbox(self, *msgs)
      end
    end

    # get msg from outbox queue
    def pop_outbox
      @store.pop_outbox(self)
    end

    def outbox_size
      @store.outbox_size(self)
    end

    protected

    # Stolen from Rack::Abstract::Id
    def generate_sid
      "%0#{@options[:sidbits] / 4}x" %
        rand(2**@options[:sidbits] - 1)
    end
  end
end

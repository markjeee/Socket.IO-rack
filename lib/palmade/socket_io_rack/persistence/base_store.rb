module Palmade::SocketIoRack
  class Persistence
    class BaseStore
      DEFAULT_OPTIONS = { }

      def initialize(options = { })
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def persist!(session)
        raise "Not implemented"
      end

      def renew!(session)
        raise "Not implemented"
      end

      def drop!(session)
        raise "Not implemented"
      end

      # Set hash value
      def set(session, k,v)
        raise "Not implemented"
      end

      # Get hash value
      def get(session, k)
        raise "Not implemented"
      end

      def keys(session)
        raise "Not implemented"
      end

      def values(session)
        raise "Not implemented"
      end

      def size(session)
        raise "Not implemented"
      end

      def include?(session, k)
        raise "Not implemented"
      end
      alias :exists? :include?

      def delete(session, k)
        raise "Not implemented"
      end

      def push_inbox(session, *msgs)
        raise "Not implemented"
      end

      def pop_inbox(session)
        raise "Not implemented"
      end

      def inbox_size(session)
        raise "Not implemented"
      end

      def push_outbox(session, *msgs)
        raise "Not implemented"
      end

      def pop_outbox(session)
        raise "Not implemented"
      end

      def outbox_size(session)
        raise "Not implemented"
      end

      def reset
        raise "Not implemented"
      end

      def close
        raise "Not implemented"
      end

      def session_exists?(session_id)
        raise "Not implemented"
      end

      protected

      # session, points to a HASH value in Redis store
      def session_cache_key(session_id)
        "#{@options[:cache_key]}/#{session_id}".freeze
      end

      # outbox: points to a LIST (LPOP to get entries, RPUSH to enqueue)
      def outbox_cache_key(scache_key)
        "#{scache_key}/outbox".freeze
      end

      # inbox: points to a LIST (LPOP to get entries, RPUSH to enqueue)
      def inbox_cache_key(scache_key)
        "#{scache_key}/inbox".freeze
      end
    end
  end
end

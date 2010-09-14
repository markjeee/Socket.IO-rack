module Palmade::SocketIoRack
  class Persistence
    class RedisStore < BaseStore
      DEFAULT_OPTIONS = {
        :redis => {
          :host => '127.0.0.1'.freeze,
          :port => '6379'.freeze,
          :db => 0
        }
      }

      def initialize(options = { })
        super(DEFAULT_OPTIONS.merge(options))
      end

      # create the initial keys, and set their expiry
      def persist!(session)
        scache_key = session_cache_key(session.session_id)

        rcache.pipelined do
          rcache.hset(scache_key, '_created', Time.now.to_s)

          rcache.expire(scache_key, @options[:cache_expiry])
          rcache.expire(inbox_cache_key(scache_key), @options[:cache_expiry])
          rcache.expire(outbox_cache_key(scache_key), @options[:cache_expiry])
        end
      end
      alias :persist :persist!

      def drop!(session)
        scache_key = session_cache_key(session.session_id)

        rcache.pipelined do
          rcache.del(scache_key)
          rcache.del(inbox_cache_key(scache_key))
          rcache.del(outbox_cache_key(scache_key))
        end
      end
      alias :drop :drop!

      # re-extend their expiry from this time on
      def renew!(session)
        scache_key = session_cache_key(session.session_id)

        rcache.pipelined do
          rcache.expire(scache_key, @options[:cache_expiry])
          rcache.expire(inbox_cache_key(scache_key), @options[:cache_expiry])
          rcache.expire(outbox_cache_key(scache_key), @options[:cache_expiry])
        end
      end
      alias :renew :renew!

      # HSET: Set hash value
      def set(session, k,v)
        rcache.hset(session_cache_key(session.session_id), k.to_s, v)
      end

      # HGET: Get hash value
      def get(session, k)
        rcache.hget(session_cache_key(session.session_id), k.to_s)
      end

      # HKEYS
      def keys(session)
        rcache.hkeys(session_cache_key(session.session_id))
      end

      # HVALS
      def values(session)
        rcache.hvals(session_cache_key(session.session_id))
      end

      # HLEN
      def size(session)
        rcache.hlen(session_cache_key(session.session_id))
      end
      alias :length :size

      # HEXISTS
      def include?(session, k)
        rcache.hexists(session_cache_key(session.session_id), k.to_s)
      end
      alias :exists? :include?

      # HDEL
      def delete(session, k)
        rcache.hdel(session_cache_key(session.session_id), k.to_s)
      end

      # save to inbox
      def push_inbox(session, *msgs)
        pushed_count = 0
        scache_key = session_cache_key(session.session_id)
        icache_key = inbox_cache_key(scache_key)

        msgs = msgs.to_a.flatten
        rcache.pipelined do
          msgs.each do |m|
            rcache.rpush(icache_key, m)
            pushed_count += 1
          end
        end

        pushed_count
      end

      # get msg from inbox queue
      def pop_inbox(session)
        scache_key = session_cache_key(session.session_id)
        rcache.lpop(inbox_cache_key(scache_key))
      end

      def inbox_size(session)
        scache_key = session_cache_key(session.session_id)
        rcache.llen(inbox_cache_key(scache_key))
      end

      # save to outbox
      def push_outbox(session, *msgs)
        pushed_count = 0
        scache_key = session_cache_key(session.session_id)
        ocache_key = outbox_cache_key(scache_key)

        msgs = msgs.to_a.flatten
        rcache.pipelined do
          msgs.each do |m|
            rcache.rpush(ocache_key, m)
            pushed_count += 1
          end
        end

        pushed_count
      end

      # get msg from outbox queue
      def pop_outbox(session)
        scache_key = session_cache_key(session.session_id)
        rcache.lpop(outbox_cache_key(scache_key))
      end

      def outbox_size(session)
        scache_key = session_cache_key(session.session_id)
        rcache.llen(outbox_cache_key(scache_key))
      end

      def session_exists?(session_id)
        rcache.exists(session_cache_key(session_id))
      end

      def close
        unless rcache.nil?
          rcache.quit
          @rcache = nil
        end
      end

      def reset
        close
        rcache
      end

      protected

      def rcache
        if defined?(@rcache) && !@rcache.nil?
          @rcache
        else
          @rcache = Redis.new(@options[:redis])
        end
      end
    end
  end
end

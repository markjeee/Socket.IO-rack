module Palmade::SocketIoRack
  class Persistence
    class MemoryStore < BaseStore
      DEFAULT_OPTIONS = { }

      class MemoryStoreObject
        attr_reader :expiry
        def set_expiry(in_seconds)
          @expiry = Time.now + in_seconds
        end

        def cleanup!
          @outbox.clear if defined?(@outbox) && !@outbox.nil?
          @inbox.clear if defined?(@inbox) && !@inbox.nil?
          @hash.clear if defined?(@hash) && !@hash.nil?
        end

        def outbox
          if defined?(@outbox)
            @outbox
          else
            @outbox = [ ]
          end
        end

        def inbox
          if defined?(@inbox)
            @inbox
          else
            @inbox = [ ]
          end
        end

        def hash
          if defined?(@hash)
            @hash
          else
            @hash = [ ]
          end
        end
      end

      def initialize(options = { })
        @options = DEFAULT_OPTIONS.merge(options)
        @sessions = { }
      end

      def persist!(session)
        sess_id = session.session_id.dup.freeze
        if @sessions.include?(sess_id)
          mso = @sessions[sess_id]
        else
          mso = @sessions[sess_id] = MemoryStoreObject.new
        end

        mso.set_expiry(@options[:cache_expiry])
      end
      alias :persist :persist!

      def renew!(session)
        sess_id = session.session_id.dup.freeze
        if @sessions.include?(sess_id)
          mso = @sessions[sess_id]
        else
          raise "Can't renew, session not found"
        end

        mso.set_expiry(@options[:cache_expiry])
      end

      def drop!(session)
        sess_id = session.session_id.dup.freeze
        if @sessions.include?(sess_id)
          mso = @sessions.delete(sess_id)
          unless mso.nil?
            mso.cleanup!
          end
        else
          raise "Can't renew, session not found"
        end
      end

      def session_exists?(session_id)
        if @sessions.include?(session_id)
          true
        else
          false
        end
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
    end
  end
end

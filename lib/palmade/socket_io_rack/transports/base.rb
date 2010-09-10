module Palmade::SocketIoRack
  module Transports
    class Base
      DEFAULT_OPTIONS = {
        :outbound_interval => 0.5, # 500ms
        :outbound_burst => 25, # send a max of 25 messages every cycle
        :outbound_max_cycle => 60 # 60 retries @ 500ms ~ 30s
      }

      CContentType = "Content-Type".freeze
      CCTtext_plain = "text/plain".freeze

      DEFAULT_HEADERS = {
        CContentType => CCTtext_plain
      }

      def connected?; @connected; end

      def initialize(resource, options = { })
        @resource = resource
        @session = nil
        @options = DEFAULT_OPTIONS.merge(options)

        @conn = nil
        @connected = false
        @outbound_timer = nil
      end

      def handle_request(env, transport_options, persistence)
        raise "Not Implemented"
      end

      def set_connection(conn)
        @conn = conn
      end

      def connected(conn)
        @connected = true

        if @session.new?
          @resource.fire_connect
        elsif
          @resource.fire_resume_connection
        end

        # start the outbound timer on next tick
        EventMachine.next_tick(method(:start_outbound_timer))
      end

      def receive_data(conn, data)
        @resource.fire_message(data)
      end

      def close(conn)
        @resource.fire_close
      end

      def unbind(conn)
        # let's try to stop it here as well, just in case
        stop_outbound_timer

        # mark as disconnected
        @connected = false
        @conn = nil
        @resource.fire_disconnected
      end

      protected

      def perform_outbound_task
        # in case we were disconnected while we're asleep, let's bail
        # out right away
        return unless connected?

        burst_count = 0
        while(m = @session.pop_outbox)
          send_data(m)

          burst_count += 1
          break if burst_count >= @options[:outbound_burst]
        end

        # TODO !!! add support for maximum outbound cycle

      ensure
        # as much as possible, let's *ensure* we've enqueued the next
        # pickup cycle
        restart_outbound_timer if connected?
      end

      def setup_session(transport_options, persistence)
        session = nil
        session_id = nil

        unless transport_options.nil?
          session_id, tm = transport_options[1..-1].split('/', 2)
          session_id = session_id.strip
        end

        if session_id.nil? || session_id.empty?
          session = persistence.create_session
        else
          session = persistence.resume_session(session_id) || persistence.create_session
        end

        session
      end

      def respond_200(msg, headers = { })
        [ 200, DEFAULT_HEADERS.merge(headers), [ msg ].flatten ]
      end

      def respond_404(msg, headers = { })
        [ 404, DEFAULT_HEADERS.merge(headers), [ msg ].flatten ]
      end

      # note, this is support on Thin. see Thin::Connection::AsyncResponse
      def respond_async
        [ -1, { }, [ ] ]
      end

      def stop_outbound_timer
        unless @outbound_timer.nil?
          EventMachine.cancel_timer(@outbound_timer)
          @outbound_timer = nil
        end
      end

      def restart_outbound_timer
        if @outbound_timer.nil?
          # only re-queue if we're still connected
          EventMachine.add_timer(@options[:outboud_interval],
                                 method(:perform_outbound_task))
        else
          raise "Looks like the inbox pick-up timer has already been started. Should not be!"
        end
      end

      def start_outbound_timer
        if @outbound_timer.nil?
          perform_outbound_task
        else
          raise "Looks like the inbox pick-up timer has already been started. Should not be!"
        end
      end
    end
  end
end

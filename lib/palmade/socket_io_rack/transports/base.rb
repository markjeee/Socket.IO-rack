# -*- encoding: binary -*-

module Palmade::SocketIoRack
  module Transports
    class Base
      DEFAULT_OPTIONS = {
        # default: 500ms pick up interval
        :outbound_interval => 0.5,

        # send a max of 25 messages every cycle
        :outbound_burst => 25,

        # set this max value to 0, to disable
        # default: 20 retries @ 500ms ~ 10s
        :outbound_max_cycle => 20,

        # set this value to 0, to disable
        # default: 4 (4 continous cycle of no traffic)
        :heartbeat_cycle_interval => 4
      }

      CContentType = "Content-Type".freeze
      CCTtext_plain = "text/plain".freeze
      DEFAULT_CONTENT_TYPE = "#{CCTtext_plain}; charset=utf-8".freeze

      DEFAULT_HEADERS = {
        CContentType => DEFAULT_CONTENT_TYPE
      }

      def connected?; @connected; end

      def initialize(resource, options = { })
        @resource = resource
        @session = nil
        @options = DEFAULT_OPTIONS.merge(options)

        @conn = nil
        @connected = false
        @outbound_timer = nil
        @outbound_cycle_count = 0
        @heartbeat_cycle_count = 0
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

      def heartbeat(cycle_count)
        @resource.fire_heartbeat(cycle_count)
      end

      protected

      def perform_outbound_task
        @outbound_timer = nil
        burst_count = 0

        # in case we were disconnected while we're asleep, let's bail
        # out right away
        return unless connected?

        begin
          while(m = @session.pop_outbox)
            send_data(m)

            burst_count += 1
            break if burst_count >= @options[:outbound_burst]
          end
        ensure
          @outbound_cycle_count += 1
          if burst_count == 0
            @heartbeat_cycle_count += 1
          else
            @heartbeat_cycle_count = 0
          end

          if connected?
            if @options[:heartbeat_cycle_interval] >= 0 && @heartbeat_cycle_count > 0 &&
                @heartbeat_cycle_count % @options[:heartbeat_cycle_interval] == 0
              heartbeat(@heartbeat_cycle_count)
            end

            if @options[:outbound_max_cycle] <= 0 ||
                @options[:outbound_max_cycle] > @outbound_cycle_count
              # as much as possible, let's *ensure* we've enqueued the next
              # pickup cycle
              restart_outbound_timer(burst_count > 0)
            else
              maxed_outbound_timer
            end
          else
            # just do nothing
          end
        end
      end

      def setup_session(transport_options, persistence)
        session = nil
        session_id = nil

        unless transport_options.nil?
          session_id, tm = transport_options[1..-1].split('/', 2)
          session_id = session_id.strip unless session_id.nil?
        end

        if session_id.nil? || session_id.empty?
          session = persistence.create_session
        else
          session = persistence.resume_session(session_id) || persistence.create_session
        end

        session
      end

      def respond_200(msg, headers = { })
        if msg.is_a?(String) || msg.is_a?(Array)
          [ 200, DEFAULT_HEADERS.merge(headers), [ msg ].flatten ]
        else
          [ 200, DEFAULT_HEADERS.merge(headers), msg ]
        end
      end

      def respond_404(msg, headers = { })
        [ 404, DEFAULT_HEADERS.merge(headers), [ msg ].flatten ]
      end

      # note, this is support on Thin. see Thin::Connection::AsyncResponse
      def respond_async
        [ -1, { }, [ ] ]
      end

      def maxed_outbound_timer
        raise "Not implemented"
      end

      def stop_outbound_timer
        unless @outbound_timer.nil?
          EventMachine.cancel_timer(@outbound_timer)
          @outbound_timer = nil
        end
      end

      def restart_outbound_timer(next_tick = false)
        if @outbound_timer.nil?
          if next_tick
            # only re-queue if we're still connected
            EventMachine.next_tick(method(:perform_outbound_task))
          else
            # only re-queue if we're still connected
            EventMachine.add_timer(@options[:outbound_interval],
                                   method(:perform_outbound_task))
          end
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

# -*- encoding: binary -*-

module Palmade::SocketIoRack
  module Transports
    class XhrPolling < Base
      Cxhrpolling = "xhr-polling".freeze
      CREQUEST_METHOD = "REQUEST_METHOD".freeze
      CPOST = "POST".freeze
      CGET = "GET".freeze

      Casynccallback = "async.callback".freeze
      Casyncclose = "async.close".freeze

      DEFAULT_OPTIONS = {
        # disable heartbeat interval by default, since
        # we're just going to disconnect due to a maxed outbound
        # check cycle
        :heartbeat_interval => 0
      }

      def initialize(resource, options = { })
        super(resource, DEFAULT_OPTIONS.merge(options))
      end

      def transport_name; Cxhrpolling; end

      def handle_request(env, transport_options, persistence)
        session = setup_session(transport_options, persistence)

        if !session.nil?
          @resource.initialize_session!(@session = session)

          case env[CREQUEST_METHOD]
          when CPOST
            # incoming message from client, can be optimized to just
            # parse the encoded post form data. but i'm lazy to do it
            # for now, so, let's just take advanage of Rack::Request.
            pd = Rack::Request.new(env).POST["data"]
            receive_data(env, pd) unless pd.nil? || pd.empty?

            [ true, respond_200("ok") ]
          when CGET
            set_connection(env)

            # trigger the connected event
            connected(env)

            [ true, respond_async ]
          else
            [ false, nil ]
          end
        else
          [ true, respond_404("Session not found") ]
        end
      end

      def set_connection(conn)
        super

        # Let's register our unbind method to the close action, just
        # in case something abruptly stops or when the connection has
        # been closed, we can do some clean-up. Note, Thin wraps the
        # execution in ensure and rescue statements, so hopefully, we
        # will eventually be called to perform proper clean-up
        conn[Casyncclose].callback do
          unbind(conn)
        end

        # Added here, just in case an error callback is called, though
        # Thin don't seem to call this callback at all. Only calls succeed.
        conn[Casyncclose].errback do
          unbind(conn)
        end
      end

      def connected(conn)
        super

        # start the outbound timer on next tick, unless there are
        # already some reply already queued
        unless send_body_ready?
          EventMachine.next_tick(method(:start_outbound_timer))
        end
      end

      def send_data(data)
        if connected?
          if send_body_ready?
            @send_body.push(data)
          else
            @send_body = [ data ]

            # queue sending of final http response on next EM cycle
            # only set it *one* time
            EventMachine.next_tick(method(:send_final_http_response))
          end
        else
          raise "Sending data on a disconnected connection"
        end
      end

      def send_final_http_response
        if connected?
          @conn[Casynccallback].call(respond_200(@send_body))
        else
          raise "Can't send the final response, we're already disconnected"
        end
      end

      def unbind(conn)
        # just do some clean-up as needed
        @send_body.clear if defined?(@send_body)
        @send_body = nil

        super
      end

      def send_body_ready?
        defined?(@send_body) && !@send_body.nil?
      end

      def maxed_outbound_timer
        send_data("") if connected?
      end
    end
  end
end

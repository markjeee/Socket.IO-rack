module Palmade::SocketIoRack
  module Transports
    class XhrPolling < Base
      Cxhrpolling = "xhr-polling".freeze
      CREQUEST_METHOD = "REQUEST_METHOD".freeze
      CPOST = "POST".freeze
      CGET = "GET".freeze

      Casynccallback = "async.callback".freeze
      Casyncclose = "async.close".freeze

      def transport_name; Cxhrpolling; end

      def handle_request(env, transport_options, persistence)
        session = setup_session(transport_options, persistence)

        if !session.nil?
          @resource.setup_session(@session = session)

          # TODO: Implement this!!!
          case env[CREQUEST_METHOD]
          when CPOST
            # incoming message from client

            [ true, respond_200("") ]
          when CGET
            set_connection(env)

            # trigger the connected event
            connected(env)

            [ true, respond_async ]
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

      def send_data(data)
        if connected?
          if defined?(@send_body)
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
          # TODO !!!! Implement sending the final response for
          # xhr-polling method
          async_callback = @conn[Casynccallback]
        else
          raise "Can't send the final response, we're already disconnected"
        end
      end
    end
  end
end

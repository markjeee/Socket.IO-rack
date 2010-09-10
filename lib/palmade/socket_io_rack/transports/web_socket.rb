module Palmade::SocketIoRack
  module Transports
    class WebSocket < Base
      Cwebsocket = "websocket".freeze
      CWebSocket = "WebSocket".freeze
      CUpgrade = "Upgrade".freeze
      CConnection = "Connection".freeze
      Cws_handler = "ws_handler".freeze

      def transport_name; Cwebsocket; end

      def handle_request(env, transport_options, persistence)
        session = setup_session(transport_options, persistence)

        # return a request for upgrade connection, which will trigger
        # the thin_connection handler to perform the WebSocket
        # handshake. This requires the custom thin backend/connection
        # built-into palmade/puppet_master
        #
        # see:
        # http://github.com/palmade/puppet_master.
        if !session.nil?
          @resource.initialize_session!(@session = session)

          [ true, [ 101,
                    {
                      CConnection => CUpgrade,
                      CUpgrade => CWebSocket,
                      Cws_handler => self
                    },
                    [ ] ]
          ]
        else
          [ true, respond_404("Session not found") ]
        end
      end

      def send_data(data)
        if connected?
          @conn.send_data_websocket(data)
        else
          raise "Sending data on a disconnected connection"
        end
      end
    end
  end
end

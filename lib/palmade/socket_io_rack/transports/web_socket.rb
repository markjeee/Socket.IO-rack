module Palmade::SocketIoRack
  module Transports
    class WebSocket < Base
      Cwebsocket = "websocket".freeze
      CWebSocket = "WebSocket".freeze
      CUpgrade = "Upgrade".freeze
      CConnection = "Connection".freeze
      Cws_handler = "ws_handler".freeze

      def transport_name; Cwebsocket; end

      def initialize(resource, options = { })
        super
        @conn = nil
     end

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

      def set_connection(conn)
        @conn = conn
      end

      def connected(conn)
        # only fire connect, if we have a new session
        @resource.fire_connect if @session.new?
      end

      def receive_data(conn, data)
        @resource.fire_message(data)
      end

      def close(conn)
        @resource.fire_close
      end

      def unbind(conn)
        @resource.fire_disconnected
      end

      def send_data(data)
        @conn.send_data_websocket(data)
      end
    end
  end
end

module Palmade::SocketIoRack
  module Transports
    Cwebsocket = "websocket".freeze

    class WebSocket
      DEFAULT_OPTIONS = { }

      def transport_name; Cwebsocket; end

      def initialize(resource, options = { })
        @options = DEFAULT_OPTIONS.merge(options)
        @resource = resource
        @conn = nil
      end

      def set_connection(conn)
        @conn = conn
      end

      def connected(conn)
        @resource.fire_connect
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

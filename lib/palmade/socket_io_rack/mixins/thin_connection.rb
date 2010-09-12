# -*- encoding: binary -*-

module Palmade::SocketIoRack
  module Mixins
    module ThinConnection
      CWebSocket = "WebSocket".freeze
      CUpgrade = "Upgrade".freeze
      CConnection = "Connection".freeze

      def self.included(thin_conn)
        thin_conn.class_eval do
          alias :post_process_without_socket_io_rack :post_process
          alias :post_process :post_process_with_socket_io_rack
        end
      end

      def post_process_with_socket_io_rack(result)
        return unless result

        # Status code -1 indicates that we're going to respond later (async).
        if (result = result.to_a).first == -1
          # this is added here to support the rails reloader when in
          # development mode. it attaches a body wrap, that expects the
          # web server to call the 'close' method on the body
          # provided. to finish the request, which triggers the
          # reloader to unload dynamically loaded objects and unlock the
          # global mutex.
          result.last.close if result.last.respond_to?(:close)

          return
        end

        # based on the result, let's check if we're requesting the
        # client to upgrade to WebSocket, if so, let's change our state
        # to that. The 'result', maybe also contain the receive_data and
        # send_data handler, that we will attach to this connection.
        websocket_upgrade!(result) if websocket_upgrade?(result)

        # The result object at this point is already an Array. we just
        # called .to_a, which in Rack::Response, also works as 'finish'
        # method. To avoid double-finishing our result, we just call it
        # once here.
        post_process_without_socket_io_rack(result)
      end

      def websocket_upgrade?(result)
        status = result[0].to_i
        headers = result[1]

        # "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        if status == 101 && headers[CConnection] == CUpgrade &&
            headers[CUpgrade] == CWebSocket
          true
        else
          false
        end
      end

      def websocket_upgrade!(result)
        # let's add the web socket extensions to this connection instance
        self.extend(Mixins.const_get(:ThinWebSocketConnection))
        websocket_upgrade!(result)
      end
    end
  end
end

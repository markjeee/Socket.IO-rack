module Palmade::SocketIoRack
  module Transports
    class FlashSocket < WebSocket
      Cflashsocket = "flashsocket".freeze

      def transport_name; Cflashsocket; end
    end
  end
end
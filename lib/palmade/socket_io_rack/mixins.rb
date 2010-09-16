module Palmade::SocketIoRack
  module Mixins
    autoload :Thin, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/mixins/thin')
    autoload :ThinConnection, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/mixins/thin_connection')
    autoload :ThinFlashSocketConnection, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/mixins/thin_flashsocket_connection')
    autoload :ThinWebSocketConnection, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/mixins/thin_websocket_connection')
  end
end

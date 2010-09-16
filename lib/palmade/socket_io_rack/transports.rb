module Palmade::SocketIoRack
  module Transports
    autoload :Base, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports/base')
    autoload :WebSocket, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports/web_socket')
    autoload :FlashSocket, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports/flash_socket')
    autoload :XhrPolling, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports/xhr_polling')
    autoload :XhrMultipart, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports/xhr_multipart')
  end
end

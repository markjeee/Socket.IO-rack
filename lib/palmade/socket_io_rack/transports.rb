module Palmade::SocketIoRack
  module Transports
    autoload :WebSocket, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports/web_socket')
    autoload :XhrPolling, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports/xhr_polling')
  end
end
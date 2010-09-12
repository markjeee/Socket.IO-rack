SOCKET_IO_RACK_LIB_DIR = File.expand_path(File.dirname(__FILE__)) unless defined?(SOCKET_IO_RACK_LIB_DIR)
SOCKET_IO_RACK_ROOT_DIR = File.expand_path(File.join(SOCKET_IO_RACK_LIB_DIR, '../..')) unless defined?(SOCKET_IO_RACK_ROOT_DIR)

require 'rubygems'
require 'logger'

module Palmade
  module SocketIoRack
    def self.logger=(l); @logger = l; end
    def self.logger; @logger ||= Logger.new(STDOUT); end

    autoload :Middleware, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/middleware')
    autoload :Base, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/base')
    autoload :Transports, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/transports')
    autoload :Persistence, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/persistence')
    autoload :Session, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/session')
    autoload :Mixins, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/mixins')

    autoload :EchoResource, File.join(SOCKET_IO_RACK_LIB_DIR, 'socket_io_rack/echo_resource')
  end
end

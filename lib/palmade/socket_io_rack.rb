SOCKET_IO_RACK_LIB_DIR = File.expand_path(File.dirname(__FILE__)) unless defined?(SOCKET_IO_RACK_LIB_DIR)
SOCKET_IO_RACK_ROOT_DIR = File.expand_path(File.join(CANDY_WRAPPER_LIB_DIR, '../..')) unless defined?(SOCKET_IO_RACK_ROOT_DIR)

require 'rubygems'
require 'logger'

module Palmade
  module SocketIoRack
    def self.logger=(l); @logger = l; end
    def self.logger; @logger ||= Logger.new(STDOUT); end
  end
end

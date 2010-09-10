require 'rubygems'
require 'test/unit'
require 'pp'

root_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require File.join(root_path, 'lib/palmade/socket_io_rack')

class MockWebSocketConnection
  attr_accessor :data
  def initialize
    @data = [ ]
  end

  def send_data_websocket(data)
    @data.push(data)
  end
end

class MockWebRequest
  def initialize(env = { }, &block)
    @response = block
    @env = {
      'async.close' => EventMachine::DefaultDeferrable.new,
      'async.callback' => method(:async_callback)
    }.merge(env)
  end

  def async_callback(result)
    unless @response.nil?
      @response.call(result)
    end

    @env['async.close'].succeed
  end

  def [](k)
    @env[k]
  end
end

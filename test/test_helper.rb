require 'rubygems'
require 'pp'

gem 'rack'
require 'rack'

root_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require File.join(root_path, 'lib/palmade/socket_io_rack')

class MockWebSocketHandler
  attr_reader :conn
  attr_reader :reader

  def set_connection(conn)
    @conn = conn
  end

  def connected(conn)
  end

  def recieve_data(conn, data)
    (@data ||= [ ]).push(data)
  end

  def close(conn)
  end

  def unbind(conn)
    @conn = nil
  end

  def connected?
    !@conn.nil?
  end
end

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
  attr_reader :data
  attr_reader :env
  attr_reader :response

  def initialize(env = { }, &block)
    @post_process = block
    @env = {
      'async.close' => EventMachine::DefaultDeferrable.new,
      'async.callback' => method(:async_callback)
    }.merge(env)
    @data = [ ]
  end

  def async_callback(result)
    @response = Rack::Response.new
    unless @post_process.nil?
      @post_process.call(result)
    end

    bd = result.last
    if bd.respond_to?(:callback)
      @response.body = bd
      bd.callback { terminate_request }
    else
      terminate_request
    end
  end

  def terminate_request
    @env['async.close'].succeed
  end

  def send_data(data)
    @data.push(data)
  end

  def [](k)
    @env[k]
  end
end

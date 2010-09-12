# -*- encoding: binary -*-

require 'rubygems'
gem 'thin'
require 'thin'

Thin.send(:include, Palmade::SocketIoRack::Mixins::Thin)
class Thin::Connection
  def send_data(data)
    (@data ||= [ ]).push(data)
  end
end

class MixinsThinTest < Test::Unit::TestCase
  def setup
  end

  def thin_klass
    ::Thin
  end

  def thin_conn_klass
    ::Thin::Connection
  end

  def test_mixin
    assert(thin_conn_klass.include?(Palmade::SocketIoRack::Mixins::ThinConnection), "Thin connection mixin not included")

    conn = thin_conn_klass.new(1)
    assert(conn.respond_to?(:websocket_upgrade?), "Thin::Connection missing websocket_upgrade? method")
    assert(conn.respond_to?(:websocket_upgrade!), "Thin::Connection missing websocket_upgrade! method")
  end

  def test_websocket_mixin
    conn = Thin::Connection.new(1)
    conn.extend(Palmade::SocketIoRack::Mixins::ThinWebSocketConnection)

    assert(conn.respond_to?(:post_init_with_websocket), "Thin::Connection missing extended :post_init method")
    assert(conn.respond_to?(:receive_data_with_websocket), "Thin::Connection missing extended :receive_data method")
    assert(conn.respond_to?(:unbind_with_websocket), "Thin::Connection missing extended :unbind method")

    conn2 = Thin::Connection.new(2)
    assert(!conn2.respond_to?(:post_init_with_websocket), "Default Thin::Connection has been extended")
  end

  def test_websocket_upgrade
    ws_handler = MockWebSocketHandler.new

    sec_key1 = generate_key
    sec_key2 = generate_key
    sec_key3 = generate_key3
    expected_digest = security_digest(sec_key1, sec_key2, sec_key3)
    assert(expected_digest.length == 16, "security digest generated is wrong")

    env = {
      "HTTP_SEC_WEBSOCKET_KEY1" => sec_key1,
      "HTTP_SEC_WEBSOCKET_KEY2" => sec_key2,
      "HTTP_ORIGIN" => "localhost",
      "Connection" => "Upgrade",
      "Upgrade" => "Connection"
    }

    result = [
              101,
              {
                "Connection" => "Upgrade",
                "Upgrade" => "WebSocket",
                "ws_handler" => ws_handler
              },
              ""
             ]

    conn = thin_klass.const_get(:Connection).new(1)
    conn.can_persist!
    conn.post_init
    conn.request.env.merge!(env)
    conn.request.body.write(sec_key3)
    conn.request.body.rewind

    assert(conn.request.persistent?, "request connection not persistent")
    assert(!conn.respond_to?(:post_init_with_websocket), "connection already extened")

    conn.post_process(result)

    #pp env
    #pp conn.request.env['rack.input'].read
    #pp result
    #pp expected_digest

    assert(ws_handler.conn == conn, "ws_handler connection not set")
    assert(result.last.length == 16, "expected security digest is of different length")
    assert(result.last == expected_digest, "expected security digest is wrong")

    assert(conn.websocket_connected?, "websocket not connected")
    assert(conn.websocket?, "websocket connection not properly set")
  end

  def security_digest(key1, key2, key3)
    bytes1 = websocket_key_to_bytes(key1)
    bytes2 = websocket_key_to_bytes(key2)
    Digest::MD5.digest(bytes1 + bytes2 + key3)
  end

  def websocket_key_to_bytes(key)
    num = key.gsub(/[^\d]/n, "").to_i() / key.scan(/ /).size
    [num].pack("N")
  end

  def generate_key3
    [rand(0x100000000)].pack("N") + [rand(0x100000000)].pack("N")
  end

  NOISE_CHARS = ("\x21".."\x2f").to_a() + ("\x3a".."\x7e").to_a()
  def generate_key
    spaces = 1 + rand(12)
    max = 0xffffffff / spaces
    number = rand(max + 1)
    key = (number * spaces).to_s()
    (1 + rand(12)).times() do
      char = NOISE_CHARS[rand(NOISE_CHARS.size)]
      pos = rand(key.size + 1)
      key[pos...pos] = char
    end
    spaces.times() do
      pos = 1 + rand(key.size - 1)
      key[pos...pos] = " "
    end
    key
  end
end

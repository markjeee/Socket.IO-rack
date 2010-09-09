class TestTransport < Test::Unit::TestCase
  class MockWebSocketConnection
    attr_accessor :data
    def initialize
      @data = [ ]
    end

    def send_data_websocket(data)
      @data.push(data)
    end
  end

  def test_websocket_new_connect
    p = Palmade::SocketIoRack::Persistence.new
    b = Palmade::SocketIoRack::Base.new
    ws_conn = MockWebSocketConnection.new

    wst = nil
    assert_nothing_raised { wst = b.initialize_transport!("websocket") }
    assert(wst.kind_of?(Palmade::SocketIoRack::Transports::WebSocket), "returned the wrong transport")

    response = nil
    performed = false

    performed, response = wst.handle_request({ }, nil, p)

    assert(b.session.new?, "session for resource was not properly initialize")
    assert(performed, "request was not performed properly")
    assert(response.first == 101, "response did not contain an http 101 protocol change request")

    wst.set_connection(ws_conn)
    wst.connected(ws_conn)

    assert(!b.session.new?, "session was not persisted properly")
    assert(!ws_conn.data.empty?, "connected event did not reply with the session id")

    encoded_session_id = b.send(:encode_messages, [ b.session.session_id ])
    assert(ws_conn.data.first == encoded_session_id, "reply data is different from session_id")
  end
end

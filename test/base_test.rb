class BaseTest < Test::Unit::TestCase
  def setup
  end

  def test_decode_messages
    b = Palmade::SocketIoRack::Base.new

    test_msg = "~m~5~m~Hello~m~2~m~Yo"
    msgs = nil

    assert_nothing_raised { msgs = b.send(:decode_messages, test_msg) }
    assert(msgs.size == 2, "wrong number of parsed messages")
    assert(msgs[0] == "Hello", "wrong first message")
    assert(msgs[1] == "Yo", "wrong second message")
  end

  def test_encode_messages
    b = Palmade::SocketIoRack::Base.new

    test_msg = "~m~5~m~Hello~m~2~m~Yo"
    data = nil

    assert_nothing_raised { data = b.send(:encode_messages, [ "Hello", "Yo" ]) }
    assert(data == test_msg, "encoded message is wrong")
  end
end

class XhrPollingTest < Test::Unit::TestCase
  def setup
    gem 'eventmachine', '>= 0.12.10'
    require 'eventmachine'
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end

  def test_new_connect
    EM.run do
      EM.next_tick do
        p = Palmade::SocketIoRack::Persistence.new
        b = Palmade::SocketIoRack::Base.new

        env = MockWebRequest.new("REQUEST_METHOD" => "GET") do |result|
          assert(result.first == 200, "not an HTTP 200 response")
          assert(result.last.size == 3, "final response is of wrong size")
        end

        xpt = nil
        assert_nothing_raised { xpt = b.initialize_transport!("xhr-polling") }
        assert(xpt.kind_of?(Palmade::SocketIoRack::Transports::XhrPolling), "returned the wrong transport")

        response = nil
        performed = false
        performed, response = xpt.handle_request(env, nil, p)

        assert(performed, "original request not performed")
        assert(response.first == -1, "response is not an async response")

        session_id = b.session.session_id
        assert(session_id.kind_of?(String), "wrong session id value")

        b.reply "Hello", "World"
        b.reply "More", "Hello", "World"

        EM.next_tick do
          assert(!xpt.connected?, "xpt was not disconnected")
          b.reply "This", "is", "for", "something", "later"

          xpt = nil
          assert_nothing_raised { xpt = b.initialize_transport!("xhr-polling") }
          assert(xpt.kind_of?(Palmade::SocketIoRack::Transports::XhrPolling), "returned the wrong transport")

          env = MockWebRequest.new("REQUEST_METHOD" => "GET") do |result|
            assert(result.first == 200, "not an HTTP 200 response")
            assert(result.last.size == 2, "final response is of wrong size")

            EM.next_tick do
              assert(!xpt.connected?, "xpt was not disconnected (resume)")

              EM.stop
            end
          end

          to = "/#{session_id}"
          response = nil
          performed = false
          performed, response = xpt.handle_request(env, to, p)

          assert(performed, "resumed request not performed")
          assert(response.first == -1, "response is not async (resume)")

          b.reply "This", "is", "a", "reply", "from", "the", "resumed", "sessions"
        end
      end
    end
  end
end

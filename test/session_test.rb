class TestSession < Test::Unit::TestCase
  def test_success
    assert(true, "WTF?!?")
  end

  def setup
    gem 'redis', '>= 2.0.5'
    require 'redis'
    require 'time'

    create_persistence
  end

  def test_rcache
    rcache = @persistence.rcache
    assert_not_nil(rcache, "Redis cache not defined on persistence")
    assert(rcache.kind_of?(Redis), "rcache is not a Redis client object")

    test_cache_key = "Socket.IO-rack/persistence/test"
    assert(rcache.set(test_cache_key, "1") == "OK", "Fail to set test cache key")
    assert(rcache.del(test_cache_key) === true, "Fail to delete test cache key")

    assert(@persistence.reset != rcache, "reset returned the same rcache connection object")
    assert(rcache.ping == "PONG", "rcache is alive")
    assert_nil(@persistence.close, "close not successful")
  end

  def test_create_session
    session = @persistence.create_session

    assert(session.kind_of?(Palmade::SocketIoRack::Session), "session returned is not the proper object")
    assert(session.session_id.kind_of?(String), "session id is not a string")
    assert(session.session_id.length == (session.options[:sidbits] / 4), "session_id is not of proper length")

    assert(session.send(:session_cache_key).kind_of?(String), "invalid session cache key value")
    assert(session.send(:session_cache_key).include?(session.options[:cache_key]), "invalid session cache key value")
    assert(session.send(:inbox_cache_key).kind_of?(String), "invalid inbox cache key value")
    assert(session.send(:inbox_cache_key).include?(session.send(:session_cache_key)), "invalid inbox cache key value")
    assert(session.send(:outbox_cache_key).kind_of?(String), "invalid outbox cache key value")
    assert(session.send(:outbox_cache_key).include?(session.send(:session_cache_key)), "invalid inbox cache key value")

    assert(session.options[:cache_expiry] == @persistence.options[:cache_expiry], "created session has different option values")
    assert(session.options[:sidbits] == @persistence.options[:sidbits], "created session has different option values")
    assert(session.options[:cache_key] == @persistence.options[:cache_key], "created session has different option values")
  end

  def test_session_persist
    session = @persistence.create_session

    rcache = session.send(:rcache)
    session_cache_key = session.send(:session_cache_key)

    assert(session.persist! == session, "returned value of persist! is wrong")
    assert(rcache.exists(session_cache_key), "persisted session key does not exists")

    created = rcache.hget(session_cache_key, "_created")
    assert(created.kind_of?(String), "created field not set properly")
    assert(Time.now - Time.parse(created) < 1, "created time is too far away")

    assert(rcache.ttl(session_cache_key) <= session.options[:cache_expiry], "expire is set way into the future")

    assert(session.drop! == session, "returned value of drop! is wrong")
    assert(!rcache.exists(session_cache_key), "drop did not removed session cache key")
    assert(!rcache.exists(session.send(:inbox_cache_key)), "drop did not removed inbox cache key")
    assert(!rcache.exists(session.send(:outbox_cache_key)), "drop did not removed outbox cache key")
  end

  def test_session_resume
    session = @persistence.create_session
    rcache = session.send(:rcache)
    session_id = session.session_id
    session_cache_key = session.send(:session_cache_key)

    session.persist!

    found_session = @persistence.resume_session(session_id)
    assert(found_session.kind_of?(Palmade::SocketIoRack::Session), "resume_session returned value is wrong")
    assert(found_session.session_id == session_id, "found session has a wrong session id")
    assert(!found_session.new?, "found session is new!")

    assert(found_session.renew! == found_session, "returned value of renew! is wrong")
    assert(rcache.ttl(session_cache_key) <= session.options[:cache_expiry], "expire is set way into the future")

    found_session.drop!
  end

  def test_session_variables
    session = @persistence.create_session
    session.persist!

    test_value = "value"
    test_key = "test"

    session[test_key] = test_value
    assert(session[test_key] == test_value, "retrieved test value is not the same as the originally set value")
    assert(session.size == 2, "size method returns wrong value")
    assert(session.include?(test_key), "include counldn't find test key")
    assert(session.keys.include?(test_key), "keys method returns wrong value")
    assert(session.values.include?(test_value), "values method returns wrong values")

    session.drop!

    assert(session.size == 0, "size method returns wrong value (after drop)")
    assert(!session.include?(test_key), "include counldn't find test key (after drop)")
    assert(!session.keys.include?(test_key), "keys method returns wrong value (after drop)")
    assert(!session.values.include?(test_value), "values method returns wrong values (after drop)")

    assert_raises(Palmade::SocketIoRack::Session::SessionError,
                  "should not be able to set in a dropped session") { session[test_key] = test_value }
  end

  def test_session_queues
    session = @persistence.create_session
    session.persist!

    assert(session.push_inbox("Hello", "World") == 2, "pushed count is wrong")
    assert(session.inbox_size == 2, "inbox queue size is wrong")
    assert(session.pop_inbox == "Hello", "1st pop value is wrong")
    assert(session.pop_inbox == "World", "2nd pop value is wrong")

    assert(session.push_outbox("Hello", "World") == 2, "pushed count is wrong")
    assert(session.outbox_size == 2, "inbox queue size is wrong")
    assert(session.pop_outbox == "Hello", "1st pop value is wrong")
    assert(session.pop_outbox == "World", "2nd pop value is wrong")

    session.drop!

    assert_raises(Palmade::SocketIoRack::Session::SessionError,
                  "should not be able to push to a dropped session") { session.push_inbox("Hello") }

    assert(session.outbox_size == 0, "inbox queue size is wrong")
    assert_nil(session.pop_outbox, "1st pop value is wrong (after drop)")
    assert_nil(session.pop_outbox, "2nd pop value is wrong (after drop)")
  end

  protected

  def create_persistence
    @persistence = Palmade::SocketIoRack::Persistence.new
  end
end

class SessionTest < Test::Unit::TestCase
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

    test_value = "value"
    test_key = :test

    session[test_key] = test_value
    assert(session[test_key] == test_value, "retrieved test value is not the same as the originally set value")
  end

  def test_session_queues
    session = @persistence.create_session
  end

  protected

  def create_persistence
    @persistence = Palmade::SocketIoRack::Persistence.new
  end
end

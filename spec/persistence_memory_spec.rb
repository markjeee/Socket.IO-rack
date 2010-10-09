require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

module Palmade::SocketIoRack
  class Persistence
    describe MemoryStore do
      before(:all) do
        gem 'redis', '>= 2.0.5'
        require 'redis'
        require 'time'

        @persistence = Palmade::SocketIoRack::Persistence.new
      end

      context "trivial behaviour" do
        it "should instantiate" do
          Palmade::SocketIoRack::Persistence::MemoryStore.new
        end

        it "should use memory store (as default)" do
          store = @persistence.store

          store.should be_an_instance_of Palmade::SocketIoRack::Persistence::MemoryStore
        end
      end

      context "session" do
        it "should create a new session" do
          sess = @persistence.create_session

          sess.should be_an_instance_of Palmade::SocketIoRack::Session
          sess.new?.should be_true
          sess.dropped?.should be_false
          sess.session_id.should_not be_nil
          sess.session_id.length.should == 32
        end

        it "should persist and resume a new session" do
          sess = @persistence.create_session
          sess_id = sess.session_id

          lambda { sess.persist! }.should_not raise_exception

          resumed_sess = @persistence.resume_session(sess_id)
          resumed_sess.should_not == sess
          resumed_sess.session_id.should == sess_id

          lambda { sess.renew! }.should_not raise_exception
        end
      end

      class MemoryStore
        context MemoryStoreObject do
          it "should instantiate" do
            Palmade::SocketIoRack::Persistence::MemoryStore::MemoryStoreObject.new
          end

          it "should cleanup" do
            mso = Palmade::SocketIoRack::Persistence::MemoryStore::MemoryStoreObject.new
            mso.inbox.push "PUSH 1"
            mso.inbox.size.should == 1
            mso.inbox.first == "PUSH 1"

            lambda { mso.cleanup! }.should_not raise_exception

            mso.inbox.size.should be_zero
            mso.outbox.size.should be_zero
            mso.hash.size.should be_zero
          end
        end
      end
    end
  end
end

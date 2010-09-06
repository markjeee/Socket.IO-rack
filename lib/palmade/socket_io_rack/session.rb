module Palmade::SocketIoRack
  class Session
    DEFAULT_OPTIONS = {
      :sidbits => 128
    }

    attr_reader :session_id

    def initialize(persistence, sess_id = nil, options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @persistence = persistence

      if sess_id.nil?
        new!
        @session_id = generate_sid
      else
        not_new!
        @session_id = sess_id
      end
    end

    def new?; @new; end
    def new!; @new = true; end
    def not_new!; @new = false; end

    # save to outbox
    def outgoing_message(msg)
    end

    # save to inbox
    def incoming_message(msg)
    end

    # Stolen from Rack::Abstract::Id
    def generate_sid
      "%0#{@options[:sidbits] / 4}x" %
        rand(2**@options[:sidbits] - 1)
    end
  end
end

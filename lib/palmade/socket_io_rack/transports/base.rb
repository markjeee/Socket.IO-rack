module Palmade::SocketIoRack
  module Transports
    class Base
      DEFAULT_OPTIONS = { }

      CContentType = "Content-Type".freeze
      CCTtext_plain = "text/plain".freeze

      def initialize(resource, options = { })
        @resource = resource
        @session = nil
        @options = DEFAULT_OPTIONS.merge(options)
      end

      def handle_request(env, transport_options, persistence)
        raise "Not Implemented"
      end

      def setup_session(transport_options, persistence)
        session = nil
        session_id = nil

        unless transport_options.nil?
          session_id, tm = transport_options[1..-1].split('/', 2)
          session_id = session_id.strip
        end

        if session_id.nil? || session_id.empty?
          session = persistence.create_session
        else
          session = persistence.resume_session(session_id) || persistence.create_session
        end

        session
      end

      def respond_404(msg)
        [ 404, { CContentType => CCTtext_plain }, [ msg ] ]
      end

      # note, this is support on Thin. see Thin::Connection::AsyncResponse
      def respond_async
        [ -1, { }, [ ] ]
      end
    end
  end
end

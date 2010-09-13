# -*- encoding: binary -*-

module Palmade::SocketIoRack
  module Mixins
    module ThinWebSocketConnection
      # initialize web socket connection state to :handshake. this is
      # the default state, irregardless if this is a websocket
      # connection or not.
      #
      # other states are :
      #
      #   :connected
      #   :terminated
      #   :unbinded
      #
      # the :terminated state will not be on for a long time, since
      # this is the last state to set the connection to, when the
      # connection is about to go down. :unbinded is when the
      # connection has already been disconnected (set when unbind is
      # called by eventmachine)
      #
      # @ws_state = :handshake

      # A WebSocket handler/callback provided by the application when
      # making a response to upgrade the current connection to
      # WebSocket. This handler must respond to the following methods:
      #
      #   # 'conn' is passed here, just in case ws_handler is a
      #   # singleton object and needs to map conn to actual handler.
      #   # 'body' is the Thin::Request#body
      #   receive_data(conn, body)
      #
      #   # 'conn' is this thin connection
      #   set_connection(conn)
      #
      #   # 'conn' is this thin connection
      #   close(conn)
      #
      #   # this connection is being disconnected
      #   unbind(conn)
      #
      # @ws_handler = nil

      Cbinary = 'binary'.freeze
      CWebSocket = "WebSocket".freeze
      CUpgrade = "Upgrade".freeze
      CConnection = "Connection".freeze
      CSecWebSocketOrigin = "Sec-WebSocket-Origin".freeze
      CSecWebSocketLocation = "Sec-WebSocket-Location".freeze
      CContentLength = "Content-Length".freeze

      CHTTP_ORIGIN = "HTTP_ORIGIN".freeze
      CHTTP_SEC_WEBSOCKET_KEY1 = "HTTP_SEC_WEBSOCKET_KEY1".freeze
      CHTTP_SEC_WEBSOCKET_KEY2 = "HTTP_SEC_WEBSOCKET_KEY2".freeze

      Cws_handler = "ws_handler".freeze
      Cws_close_message = "\xff\x00".freeze
      Cws_blank_message = "\x00\xff".freeze
      Cws_frame_message = "\x00%s\xff".freeze
      Cws_regex_message = (/\A\x00(.*)\xff\Z/nm).freeze

      def self.extended(base)
        base.instance_eval do
          alias :post_init_without_websocket :post_init
          alias :post_init :post_init_with_websocket

          alias :receive_data_without_websocket :receive_data
          alias :receive_data :receive_data_with_websocket

          alias :unbind_without_websocket :unbind
          alias :unbind :unbind_with_websocket
        end
      end

      def websocket?
        websocket_connected?
      end

      def receive_data_with_websocket(data)
        receive_data_websocket(data)
      end

      def post_init_with_websocket
        post_init_without_websocket

        if defined?(@ws_state) && @ws_state == :connecting
          @ws_state = :connected
          @ws_handler.connected(self)
        end
      end

      def unbind_with_websocket
        # we have a ws_handler set, and we'd like to notify it that the
        # connection it is related to, has been disconnected or no
        # longer servicable.
        #
        # this is a default check, no need to check the ws_state, since
        # unbind can be called either with the client initiated
        # disconnection or via the terminate_request method. either
        # way, if we have a connected ws_handler, we should notify it.
        if defined?(@ws_handler) && !@ws_handler.nil?
          @ws_handler.unbind(self)
          @ws_handler = nil
          @ws_state = :unbinded
        end

        unbind_without_websocket
      end

      def terminate_websocket
        cant_persist!
        @ws_state = :terminated

        # just ignore an send_data errors, since we're terminating this
        # connection anyway.
        send_data Cws_close_message rescue nil

        terminate_request

        self
      end

      def receive_data_websocket(data)
        trace { "WS RCV: #{data}" }

        if data =~ Cws_regex_message
          @ws_handler.receive_data(self, $1)
        elsif data == Cws_close_message # closing
          @ws_handler.close(self)
          terminate_websocket
        else
          raise "Invalid data for web socket"
        end
      rescue Exception => e
        log "!!! Exception in receive_data for websocket"
        log_error e
        close_connection
      end

      if ::Thin.ruby_18?
        def send_data_websocket(data)
          trace { "WS SND: #{data}" }
          send_data(Cws_frame_message % data)
        end
      else
        def send_data_websocket(data)
          trace { "WS SND: #{data}" }
          data = data.dup.force_encoding(Cbinary) if RUBY_VERSION >= "1.9"
          send_data(Cws_frame_message % data)
        end
      end

      # from the result (Array), the websocket handler (sort of
      # functions just like an EventMachine connection)
      def websocket_upgrade!(result)
        debug { "Upgrading connection to web socket #{self}" }

        headers = result[1]

        if headers.include?(Cws_handler) && !headers[Cws_handler].nil?
          @ws_handler = headers.delete(Cws_handler)
          @ws_handler.set_connection(self)
        else
          raise "I got a WebSocket upgrade response from application, but couldn't find a valid ws_handler object"
        end

        # let's attach the handshake replies if the application did not
        # provide any. this is just a convenience code, to avoid the
        # hassle of calculating the security digest.
        unless headers.include?(CSecWebSocketOrigin)
          body = result[2]

          # this is a direct hack to clear out the body object attached to
          # the result. some frameworks expect it to be called (.each) to
          # perform additional clean-up. we're just going to mimick them
          # here, since we are replacing the body of the response with the
          # web socket digest.
          body.each { } unless body.is_a?(String)
          body.close if body.respond_to?(:close)

          # let's insert the other headers for this handshake
          headers[CSecWebSocketOrigin] = request.env[CHTTP_ORIGIN]

          req = Rack::Request.new(request.env)
          location = "#{req.scheme == 'https' ? 'wss' : 'ws'}://#{req.host_with_port}#{req.fullpath}"
          headers[CSecWebSocketLocation] = location

          sec_key1 = request.env[CHTTP_SEC_WEBSOCKET_KEY1]
          sec_key2 = request.env[CHTTP_SEC_WEBSOCKET_KEY2]

          request.body.rewind
          sec_key3 = request.body.read

          sec_digest = websocket_security_digest(sec_key1, sec_key2, sec_key3)

          #puts "SEC1: #{sec_key1.inspect}"
          #puts "SEC2: #{sec_key2.inspect}"
          #puts "SEC3: #{sec_key3.inspect}"
          #puts "SECD: #{sec_digest.inspect}"

          headers[CContentLength] = sec_digest.size.to_s

          # now, replace the body with our digest
          result[2] = sec_digest
        end

        @ws_state = :connecting
      end

      def websocket_connected?
        defined?(@ws_state) && @ws_state == :connected
      end

      def websocket_security_digest(k1, k2, k3)
        b1 = websocket_key_to_bytes(k1)
        b2 = websocket_key_to_bytes(k2)

        Digest::MD5.digest(b1 + b2 + k3)
      end

      def websocket_key_to_bytes(k)
        num = k.gsub(/[^\d]/n, "").to_i() / k.scan(/ /).size
        [ num ].pack("N")
      end
    end
  end
end


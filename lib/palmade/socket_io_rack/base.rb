# -*- encoding: utf-8 -*-

module Palmade::SocketIoRack
  class Base
    DEFAULT_OPTIONS = { }

    attr_reader :session
    attr_reader :transport

    Cxhrpolling = "xhr-polling".freeze
    Cwebsocket = "websocket".freeze

    def initialize(options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @transport = nil
      @session = nil
    end

    def initialize_transport!(tn, to = { })
      case tn
      when Cwebsocket
        @transport = Transports::WebSocket.new(self, to)
      when Cxhrpolling
        @transport = Transports::XhrPolling.new(self, to)
      else
        raise "Unsupported transport #{tn}"
      end

      @transport
    end

    def initialize_session!(sess)
      @session = sess
    end

    def on_message(msg); end # do nothing
    def on_connect; end # do nothing
    def on_resume_connection; end # do nothing
    def on_close; end # do nothing
    def on_disconnected; end # do nothing

    def fire_connect
      on_connect
      reply(session.session_id)

      @session.persist!
    end

    def fire_resume_connection
      on_resume_connection

      # TODO: Check if we have to do this every time, or only on the
      # first connection. This might pose a problem with xhr-polling,
      # which always tries to re-connect. CHECK if Socket.IO always
      # expects the first message to be the session id.
      reply(session.session_id)

      @session.renew!
    end

    def fire_message(data)
      msgs = decode_messages(data)
      msgs.each { |msg| on_message(msg) }
      @session.renew!
    end

    def fire_close
      on_close
    end

    def fire_disconnected
      on_disconnected
    end

    def reply(*msgs)
      transport.send_data(encode_messages(msgs.to_a.flatten))
    end

    def deferred_reply(*msgs)
      session.push_outbox(encode_messages(msgs.to_a.flatten))
    end

    protected

    def decode_messages(data)
      msgs = [ ]
      data = data.dup.force_encoding('UTF-8')

      loop do
        case data.slice!(0,3)
        when '~m~'
          size, data = data.split('~m~', 2)
          size = size.to_i

          case data[0,3]
          when '~j~'
            msgs.push Yajl::Parser.parse(data[3, size - 3])
          when '~h~'
            raise "Heartbeat not yet supported!"
          else
            msgs.push data[0, size]
          end

          # let's slize the message
          data.slice!(0, size)
        when nil, ''
          break
        else
          raise "Unsupported frame type #{data[0,3]}"
        end
      end

      msgs
    end

    def encode_messages(msgs)
      data = ""
      msgs.each do |msg|
        case msg
        when String
          # as-is
        else
          msg = "~j~#{Yajl::Encoder.encode(msg)}"
        end

        msg_len = msg.length
        data += "~m~#{msg_len}~m~#{msg}"
      end
      data
    end
  end
end

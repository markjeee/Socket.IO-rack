# -*- encoding: utf-8 -*-

module Palmade::SocketIoRack
  class Base
    DEFAULT_OPTIONS = { }

    attr_reader :transport

    Cxhrpolling = "xhr-polling".freeze
    Cwebsocket = "websocket".freeze

    def initialize(session_id = nil, options = { })
      @session_id = session_id
      @options = DEFAULT_OPTIONS.merge(options)
      @transport = nil
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

    def fire_connect
      # TODO: Reply with the session id
      on_connect
    end

    def fire_message(data)
      msg = decode_message(data)
      on_message(msg)
    end

    def fire_close
      on_close
    end

    def fire_disconnected
      on_disconnected
    end

    def on_message(msg); end # do nothing
    def on_connect; end # do nothing
    def on_close; end # do nothing
    def on_disconnected; end # do nothing

    def reply(msg)
      transport.send_data(encode_message(msg))
    end

    protected

    # TODO: Support multiple messages
    def decode_message(data)
      data = data.dup.force_encoding('UTF-8')

      case data.slice!(0,3)
      when '~m~'
        size, msg = data.split('~m~', 2)
        size = size.to_i

        case msg[0,3]
        when '~j~'
          msg = Yajl::Parser.parse(msg[3, size - 3])
        else
          msg = msg[0, size]
        end
      when '~h~'
        raise "Heartbeat not yet supported!"
      else
        raise "Unsupported frame type #{data[0,3]}"
      end

      msg
    end

    # TODO: Support multiple messages
    def encode_message(msg)
      case msg
      when String
        # as-is
      else
        msg = "~j~#{Yajl::Encoder.encode(msg)}"
      end

      msg_len = msg.length
      data = "~m~#{msg_len}~m~#{msg}"
    end
  end
end

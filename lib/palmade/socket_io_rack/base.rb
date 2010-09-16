# -*- encoding: utf-8 -*-

module Palmade::SocketIoRack
  class Base
    DEFAULT_OPTIONS = { }

    attr_reader :session
    attr_reader :transport

    Cxhrpolling = "xhr-polling".freeze
    Cwebsocket = "websocket".freeze
    Cflashsocket = "flashsocket".freeze
    Cxhrmultipart = "xhr-multipart".freeze

    Cmframe = "~m~".freeze
    Chframe = "~h~".freeze
    Cjframe = "~j~".freeze

    def initialize(options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @transport = nil
      @session = nil
    end

    def initialize_transport!(tn, to = { })
      case tn
      when Cwebsocket
        @transport = Transports::WebSocket.new(self, to)
      when Cflashsocket
        @transport = Transports::FlashSocket.new(self, to)
      when Cxhrpolling
        @transport = Transports::XhrPolling.new(self, to)
      when Cxhrmultipart
        @transport = Transports::XhrMultipart.new(self, to)
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
    def on_heartbeat(cycle_count); end # do nothing

    def fire_connect
      on_connect
      reply(session.session_id)

      @session.persist!
    end

    def fire_resume_connection
      on_resume_connection

      @session.renew!
    end

    def fire_message(data)
      msgs = decode_messages(data)
      msgs.each do |msg|
        case msg[0,3]
        when Chframe
          hb = msg[3..-1]

          # puts "Got HB: #{hb}"
          if session['heartbeat'] == hb
            # just got heartbeat
            session.delete('heartbeat')
          else
            # TODO: Add support for wrong heartbeat message
          end
        else
          on_message(msg)
        end
      end

      @session.renew!
    end

    def fire_close
      on_close
    end

    def fire_disconnected
      on_disconnected

      # let's remove the reference to the transport, to allow the
      # garbase collector to reclaim it
      @transport = nil
    end

    def fire_heartbeat(cycle_count)
      on_heartbeat(cycle_count)

      unless session.include?('heartbeat')
        hb = Time.now.to_s
        session['heartbeat'] = hb

        # puts "Sending HB: #{hb}"
        reply("#{Chframe}#{hb}")
      else
        # TODO: Add support for handling if a previously sent
        # heartbeat did not get a reply
      end
    end

    def reply(*msgs)
      if connected?
        transport.send_data(encode_messages(msgs.to_a.flatten))
      else
        deferred_reply(*msgs)
      end
    end

    def deferred_reply(*msgs)
      session.push_outbox(encode_messages(msgs.to_a.flatten))
    end

    def connected?
      !transport.nil? && transport.connected?
    end

    protected

    def decode_messages(data)
      msgs = [ ]
      data = data.dup.force_encoding('UTF-8') if RUBY_VERSION >= "1.9"

      loop do
        case data.slice!(0,3)
        when '~m~'
          size, data = data.split('~m~', 2)
          size = size.to_i

          case data[0,3]
          when '~j~'
            msgs.push Yajl::Parser.parse(data[3, size - 3])
          when '~h~'
            # let's have our caller process the message
            msgs.push data[0, size]
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

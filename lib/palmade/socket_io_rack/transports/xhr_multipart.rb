# -*- encoding: binary -*-

module Palmade::SocketIoRack
  module Transports
    class XhrMultipart < XhrPolling
      Cxhrmultipart = "xhr-multipart".freeze
      CREQUEST_METHOD = "REQUEST_METHOD".freeze
      CPOST = "POST".freeze
      CGET = "GET".freeze

      Casynccallback = "async.callback".freeze
      Casyncclose = "async.close".freeze
      Csocketio = "socketio".freeze

      CContentType = "Content-Type".freeze
      CCTtext_plain = "text/plain".freeze

      CCTmultipart_mixed_replace = "multipart/x-mixed-replace".freeze
      DEFAULT_CONTENT_TYPE = "#{CCTtext_plain}; charset=utf-8".freeze
      DEFAULT_MULTIPART_HEADER = "#{CContentType}: #{DEFAULT_CONTENT_TYPE}".freeze

      DEFAULT_OPTIONS = {
        # this is disabled by default with web sockets
        :outbound_max_cycle => 0,
        :multipart_boundary => Csocketio
      }

      class DeferredResponseBody
        include EventMachine::Deferrable

        attr_reader :callbacks
        attr_reader :deferred_status
        attr_reader :data

        # do nothing, since we're sending data later on
        def each; end

        def done?
          [ :succeeded, :failed ].include?(deferred_status)
        end

        SEND_DATA_CODE = "send_data(@response.body.data)".freeze
        def send_data(data)
          @data = data
          eval(SEND_DATA_CODE, callbacks.last.binding)
        ensure
          @data = nil
        end
      end

      def transport_name; Cxhrmultipart; end

      def initialize(resource, options = { })
        super(resource, DEFAULT_OPTIONS.merge(options))
      end

      def connected(conn)
        EventMachine.next_tick(method(:start_http_response))
        super
      end

      def unbind(conn)
        @deferred_bd.fail if defined?(@deferred_bd) && !@deferred_bd.nil? && !@deferred_bd.done?
        @deferred_bd = nil

        super
      end

      def send_data(data)
        if connected?
          if headers_sent?
            # if this was not the last part, let's send another marker
            if data.empty?
              @deferred_bd.send_data("#{DEFAULT_MULTIPART_HEADER}\n\n\n")
            else
              @deferred_bd.send_data("#{DEFAULT_MULTIPART_HEADER}\n\n#{data}\n--#{@options[:multipart_boundary]}\n")
            end
          elsif send_body_ready?
            @send_body.push(data)
          else
            @send_body = [ data ]
          end
        else
          raise "Sending data on a disconnected connection"
        end
      end

      def headers_sent?
        defined?(@deferred_bd) && !@deferred_bd.nil?
      end

      def start_http_response
        return unless connected?

        headers = {
          CContentType => "#{CCTmultipart_mixed_replace};boundary=\"#{@options[:multipart_boundary]}\""
        }

        @deferred_bd = DeferredResponseBody.new
        @conn[Casynccallback].call(respond_200(@deferred_bd, headers))

        # write the boundary stub, to inform the browser to expect
        # something is in the way.
        @deferred_bd.send_data("--#{@options[:multipart_boundary]}\n")

        if send_body_ready?
          while(data = @send_body.pop) do
            send_data(data)
          end
          @send_body.clear

          EventMachine.next_tick(method(:start_outbound_timer))
        end
      end

      def end_http_response
        if headers_sent?
          send_data("")
          @deferred_bd.succeed
        end
      end

      def maxed_outbound_timer
        return unless connected?

        end_http_response
      end
    end
  end
end

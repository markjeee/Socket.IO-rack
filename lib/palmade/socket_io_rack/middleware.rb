# -*- encoding: binary -*-

module Palmade::SocketIoRack
  class Middleware
    DEFAULT_OPTIONS = {
      :resources => { }
    }

    CPATH_INFO = "PATH_INFO".freeze
    CSOCKET_IO_RESOURCE = "SOCKET_IO_RESOURCE".freeze
    CSOCKET_IO_TRANSPORT = "SOCKET_IO_TRANSPORT".freeze
    CSOCKET_IO_TRANSPORT_OPTIONS = "SOCKET_IO_TRANSPORT_OPTIONS".freeze

    Cwebsocket = "websocket".freeze
    CWebSocket = "WebSocket".freeze
    CUpgrade = "Upgrade".freeze
    CConnection = "Connection".freeze
    CHTTP_UPGRADE = "HTTP_UPGRADE".freeze
    CHTTP_CONNECTION = "HTTP_CONNECTION".freeze
    Cxhrpolling = "xhr-polling".freeze
    Cws_handler = "ws_handler".freeze

    CContentType = "Content-Type".freeze
    CCTtext_plain = "text/plain".freeze

    SUPPORTED_TRANSPORTS = [ Cwebsocket,
                             Cxhrpolling ]

    def logger
      @logger ||= Palmade::SocketIoRack.logger
    end

    def initialize(app, options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @resources = options[:resources]
      @resource_paths = nil

      @app = app
    end

    def call(env)
      performed, response = call_resources(env)
      unless performed
        @app.call(env)
      else
        response
      end
    end

    protected

    def call_resources(env)
      performed = false
      response = nil

      unless @resources.empty?
        pi = Rack::Utils.unescape(env[CPATH_INFO])

        resource_paths.each do |rpath|
          if pi.index(rpath) == 0
            if pi =~ /\A#{rpath}\/([^\/]+)(\/.*)?\Z/
              transport = $~[1]
              transport_options = $~[2]

              env[CSOCKET_IO_RESOURCE] = rpath
              env[CSOCKET_IO_TRANSPORT] = transport
              env[CSOCKET_IO_TRANSPORT_OPTIONS] = transport_options

              if SUPPORTED_TRANSPORTS.include?(transport)
                case transport
                when Cwebsocket
                  performed, response = perform_websocket(env, rpath, transport, transport_options)
                when Cxhrpolling
                  performed, response = perform_xhr_polling(env, rpath, transport, transport_options)
                end
              else
                logger.error { "!!! Socket.IO ERROR: Transport not supported #{rpath} #{transport} #{transport_options}" }
                performed, response = true, not_found("Transport not supported: #{transport}, possible #{SUPPORTED_TRANSPORTS.join(', ')}")
              end

              # only perform the first match
              break if performed
            end
          end
        end
      end

      [ performed, response ]
    end

    def perform_websocket(env, rpath, transport, transport_options)
      performed = false
      response = nil

      if env[CHTTP_UPGRADE] == CWebSocket &&
          env[CHTTP_CONNECTION] == CUpgrade

        resource = create_resource(rpath,
                                   transport,
                                   transport_options)

        ws_handler = resource.initialize_transport! Cwebsocket

        performed, response = true, [ 101,
                                      {
                                        CConnection => CUpgrade,
                                        CUpgrade => CWebSocket,
                                        Cws_handler => ws_handler
                                      },
                                      [ ] ]
      end

      [ performed, response ]
    end

    # TODO: Implement xhr-polling transport
    def perform_xhr_polling(env, rpath, transport, transport_options)
      performed = false
      response = nil

      [ performed, response ]
    end

    def resource_paths
      if @resource_paths.nil?
        @resource_paths = [ ]
        @resources.keys.each do |r|
          @resource_paths.push(r)
        end
      else
        @resource_paths
      end
    end

    def not_found(msg)
      [ 404, { CContentType => CCTextplain }, [ msg ] ]
    end

    # Stolen from ActiveSupport
    def constantize(word)
      names = word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end

    # TODO: Add support for specfying session id
    def create_resource(rpath, transport, transport_options)
      rpath_options = @resources[rpath]
      session_id = nil

      case rpath_options
      when String
        rsc, rsc_options = rpath_options, nil
      when Array
        rsc, rsc_options = rpath_options[0], rpath_options[1]
      when Hash
        rsc, rsc_options = rpath_options[:resource], rpath_options[:resource_options]
      else
        raise "Unsupported rpath_options #{rpath} #{rpath_options.inspect}"
      end

      case rsc
      when String
        rsc = constantize(rsc)
        resource = rsc.new(session_id, rsc_options || { })
      when Class
        resource = rsc.new(session_id, rsc_options || { })
      else
        raise "Unsupported web socket handler #{ws_handler.inspect}"
      end

      resource
    end
  end
end

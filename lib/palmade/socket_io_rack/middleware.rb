# -*- encoding: binary -*-

module Palmade::SocketIoRack
  class Middleware
    DEFAULT_OPTIONS = {
      :resources => { },
      :persistence => { }
    }

    CPATH_INFO = "PATH_INFO".freeze
    CSOCKET_IO_RESOURCE = "SOCKET_IO_RESOURCE".freeze
    CSOCKET_IO_TRANSPORT = "SOCKET_IO_TRANSPORT".freeze
    CSOCKET_IO_TRANSPORT_OPTIONS = "SOCKET_IO_TRANSPORT_OPTIONS".freeze

    CREQUEST_METHOD = "REQUEST_METHOD".freeze
    CPOST = "POST".freeze
    CGET = "GET".freeze

    Cwebsocket = "websocket".freeze
    CWebSocket = "WebSocket".freeze
    CUpgrade = "Upgrade".freeze
    CConnection = "Connection".freeze
    CHTTP_UPGRADE = "HTTP_UPGRADE".freeze
    CHTTP_CONNECTION = "HTTP_CONNECTION".freeze
    Cflashsocket = "flashsocket".freeze
    Cxhrpolling = "xhr-polling".freeze
    Cws_handler = "ws_handler".freeze
    Cxhrmultipart = "xhr-multipart".freeze

    CContentType = "Content-Type".freeze
    CCTtext_plain = "text/plain".freeze

    SUPPORTED_TRANSPORTS = [ Cwebsocket,
                             Cflashsocket,
                             Cxhrpolling,
                             Cxhrmultipart
                           ]

    def initialize(app, options = { })
      @options = DEFAULT_OPTIONS.merge(options)
      @resources = options[:resources]
      @resource_paths = nil

      @app = app
    end

    def logger
      @logger ||= Palmade::SocketIoRack.logger
    end

    def persistence
      if defined?(@persistence)
        @persistence
      else
        @persistence = Palmade::SocketIoRack::Persistence.new(@options[:persistence])
      end
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
                when Cflashsocket
                  performed, response = perform_flashsocket(env, rpath, transport, transport_options)
                when Cxhrpolling
                  performed, response = perform_xhr_polling(env, rpath, transport, transport_options)
                when Cxhrmultipart
                  performed, response = perform_xhr_multipart(env, rpath, transport, transport_options)
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

        performed, response = resource.
          initialize_transport!(Cwebsocket).handle_request(env, transport_options, persistence)
      end

      [ performed, response ]
    end

    def perform_flashsocket(env, rpath, transport, transport_options)
      performed = false
      response = nil

      if env[CHTTP_UPGRADE] == CWebSocket &&
          env[CHTTP_CONNECTION] == CUpgrade

        resource = create_resource(rpath,
                                   transport,
                                   transport_options)

        performed, response = resource.
          initialize_transport!(Cflashsocket).handle_request(env, transport_options, persistence)
      end

      [ performed, response ]
    end

    def perform_xhr_polling(env, rpath, transport, transport_options)
      performed = false
      response = nil

      if [ CPOST, CGET ].include?(env[CREQUEST_METHOD])
        resource = create_resource(rpath,
                                   transport,
                                   transport_options)

        performed, response = resource.
          initialize_transport!(Cxhrpolling).handle_request(env, transport_options, persistence)
      end

      [ performed, response ]
    end

    def perform_xhr_multipart(env, rpath, transport, transport_options)
      performed = false
      response = nil

      if [ CPOST, CGET ].include?(env[CREQUEST_METHOD])
        resource = create_resource(rpath,
                                   transport,
                                   transport_options)

        performed, response = resource.
          initialize_transport!(Cxhrmultipart).handle_request(env, transport_options, persistence)
      end

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
      [ 404, { CContentType => CCTtext_plain }, [ msg ] ]
    end

    # Stolen from ActiveSupport
    CConstantsDelimeter = "::".freeze
    def constantize(word)
      names = word.split(CConstantsDelimeter)
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end

    def create_resource(rpath, transport, transport_options)
      rpath_options = @resources[rpath]

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
        resource = rsc.new(rsc_options || { })
      when Module
        resource = rsc
      when Class
        resource = rsc.new(rsc_options || { })
      else
        raise "Unsupported web socket handler #{ws_handler.inspect}"
      end

      resource
    end
  end
end

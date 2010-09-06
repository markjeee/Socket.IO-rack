module Palmade::SocketIoRack
  class XhrPolling < Base
    Cxhrpolling = "xhr-polling".freeze
    CREQUEST_METHOD = "REQUEST_METHOD".freeze
    CPOST = "POST".freeze
    CGET = "GET".freeze
    Casynccallback = "async.callback".freeze

    # The default setting below, sets the long-poll to 30s
    DEFAULT_OPTIONS = {
      :pickup_interval => 0.5, # 500ms
      :pickup_max_retry => 60 # 60 retries @ 500ms ~ 30s
    }

    def transport_name; Cxhrpolling; end

    def initialize(resource, options = { })
      super(resource, DEFAULT_OPTIONS.merge(options))

      @pickup_retry = 0
    end

    def handle_request(env, transport_options, persistence)
      session = setup_session(transport_options, persistence)

      if !session.nil?
        @resource.setup_session(@session = session)

        # TODO: Implement this!!!
        case env[CREQUEST_METHOD]
        when CPOST
          # incoming message from client
        when CGET
          # trigger the connected event
          connected

          # pick-up messages and respond, perform async mode in case
          # there's no queued messages
          response = pickup_and_respond(env)
        end

        [ true, response ]
      else
        [ true, respond_404("Session not found") ]
      end
    end

    # TODO: Implement picking up of messages on 'outbox' queue
    def pickup_and_respond(env, async = false)
      async_callback = env[Casyncallback]

      # pick-up outgoing messages from client
      #
      # (1) Check if there's any pending message,
      #     send right away if any

      # (2) If there's none, then go into async mode, and loop for
      #     it, until there's new message, with a given timeout
      #     for the long-poll. prolly use eventmachine for this.

      respond_async
    end

    def connected
      @resource.fire_connect if @session.new?
    end

    def receive_data(data)
      @resource.fire_message(data)
    end

    def close
      @resource.fire_close
    end

    def disconnected
      @resource.fire_disconnected
    end

    def send_data(data)
    end
  end
end

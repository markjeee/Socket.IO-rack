module Palmade::SocketIoRack
  module Mixins
    module ThinFlashSocketConnection

      def self.included(thin_conn)
        thin_conn.class_eval do
          alias :receive_data_without_flash_policy_file :receive_data
          alias :receive_data :receive_data_with_flash_policy_file
        end
      end

      def receive_data_with_flash_policy_file(data)
        # thin require data to be proper http request - in it's not
        # then @request.parse raises exception and data isn't parsed
        # by futher methods. Here we only check if it is flash
        # policy file request ("<policy-file-request/>\000") and
        # if so then flash policy file is returned. if not then
        # rest of request is handled.
        if (data == "<policy-file-request/>\000")
          # ignore errors - we will close this anyway
          send_data('<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>') rescue nil
          terminate_request
        else
          receive_data_without_flash_policy_file(data)
        end
      end

    end
  end
end
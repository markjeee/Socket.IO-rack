# -*- encoding: binary -*-

module Palmade::SocketIoRack
  module Mixins
    module Thin
      def self.included(thin)
        thin_connection = thin.const_get(:Connection)
        thin_connection.send(:include, Mixins.const_get(:ThinConnection))
        thin_connection.send(:include, Mixins.const_get(:ThinFlashSocketConnection))
      end
    end
  end
end

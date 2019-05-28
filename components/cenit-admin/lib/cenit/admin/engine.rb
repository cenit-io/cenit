module Cenit
  module Admin
    class Engine < ::Rails::Engine
      isolate_namespace Cenit::Admin

      initializer :assets do |config|
        Rails.application.config.assets.precompile += %w( cenit/**/* )
      end

      def self.on_route_draw(routing_mapper)
        routing_mapper.instance_eval do
          mount Cenit::Admin::Engine => ''
        end
      end
    end
  end
end


module CrossOrigin
  module CenitDocument
    extend ActiveSupport::Concern

    include CrossOrigin::Document

    def can_cross?(origin)
      (self.origin != :shared || ::User.current_cross_shared?) && super
    end

    module ClassMethods
      def cross_origins
        if @origins
          @origins.collect do |origin|
            if origin.respond_to?(:call)
              origin.call
            else
              origin
            end
          end.flatten.uniq.compact.collect do |origin|
            if origin.is_a?(Symbol)
              origin
            else
              origin.to_s.to_sym
            end
          end.uniq
        elsif superclass.include?(CrossOrigin::CenitDocument)
          superclass.origins
        elsif superclass.include?(CrossOrigin::Document)
          superclass.origins
        else
          CrossOrigin.names
        end
      end
    end
  end
end
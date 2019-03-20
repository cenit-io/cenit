module RailsAdmin
  module Config
    LazyModel.class_eval do
      def ready
        @model
      end
    end
  end
end

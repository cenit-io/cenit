module RailsAdmin
  class MongoffModelConfig

    def initialize(mongoff_abstract_model)
      @abtarct_model = mongoff_abstract_model
      @model = mongoff_abstract_model.model
    end

    def abstract_model
      @abtarct_model
    end

    def target
      @model
    end

    def excluded?
      false
    end

    def label
      target.data_type.title
    end

    def label_plural
      label.pluralize
    end

    def object_label_method
      :to_s
    end

    def list
      unless @list
        @list = OpenStruct.new
        @list.fields = []
        @list.scopes = []
        @list.define_singleton_method(:with) { |args| self }
        @list.visible_fields = []
        @list.filters = []
      end
      @list
    end

    def with(*args)
      self
    end

    def visible?
      true
    end

    def method_missing(method, *args, &block)
      target.send(method, *args, &block)
    end

    def respond_to?(method, include_private = false)
      super || target.respond_to?(method, include_private)
    end
  end
end
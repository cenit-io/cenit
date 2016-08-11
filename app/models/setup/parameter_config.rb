module Setup
  class ParameterConfig
    include CenitScoped

    deny :all
    allow :index, :show, :edit

    build_in_data_type

    field :value, default: ''
    field :name, type: String
    field :location, type: Symbol

    before_save do
      self.value = Cenit::Utility.json_value_of(value)
    end

    def parent
      @parent ||= get_parent
    end

    def parent_model
      parent && parent.class
    end

    private

    def get_parent
      reflect_on_all_associations(:belongs_to).each do |r|
        if (parent = send(r.name))
          return parent
        end
      end
      nil
    end
  end
end

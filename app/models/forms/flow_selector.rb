module Forms
  class FlowSelector
    include Mongoid::Document
    include AccountScoped

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    validates_presence_of :flow

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :flow do
          associated_collection_scope do
            limit = (associated_collection_cache_all ? nil : 30)
            data_type = bindings[:object].try(:data_type)
            flows_ids = Setup::Flow.all.select do |flow|
              flow.data_type.nil? ||
                (flow.translator && flow.data_type == data_type)
            end.collect(&:id)
            Proc.new { |scope| scope.any_in(id: flows_ids).limit(limit) }
          end
        end
      end
    end
  end
end

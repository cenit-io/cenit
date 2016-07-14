module Forms
  class FlowSelector
    include Mongoid::Document

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :flow, class_name: Setup::Flow.to_s, inverse_of: nil

    validates_presence_of :flow

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :flow do
          inline_edit false
          inline_add false
          associated_collection_cache_all { true }
          associated_collection_scope do
            data_type = bindings[:object].try(:data_type)
            flows_ids = Setup::Flow.all.select do |flow|
              flow.data_type.nil? ||
                (flow.translator && flow.translator.type != :Import && flow.data_type == data_type)
            end.collect(&:id)
            Proc.new { |scope|
              scope.any_in(id: flows_ids)
            }
          end
        end
      end
    end
  end
end

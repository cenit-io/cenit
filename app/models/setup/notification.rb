module Setup
  class Notification
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped

    belongs_to :flow_id, class_name: Setup::Flow.name

    field :http_status_code, type: String
    field :http_status_message, type: String
    field :count, type: Integer
    field :json_data, type: String

    def must_be_resend?
      !(200...299).include?(http_status_code)
    end

    def resend
      return unless self.must_be_resend?
      self.flow.process_json_data(self.json_data, self.id)
    end
    
    rails_admin do
      edit do
        field :flow
        field :http_status_code
        field :count
        field :http_status_message
        field :json_data
      end
      list do
        field :flow
        field :http_status_code
        field :count
        field :http_status_message
      end  
      show do
        field :_id
        field :flow
        field :http_status_code
        field :count
        field :http_status_message
        field :json_data
      end 
    end

  end
end

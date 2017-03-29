module Cenit
  OauthScope.class_eval do

    def can?(action, model)
      return false unless (data_type = model.try(:data_type))
      method =
        case action
        when :new, :upload_file
          :post
        when :update
          :update
        when :index, :show
          :get
        when :destroy
          :delete
        else
          nil
        end
      return true if super_method?(method)
      criteria = access_by_ids.criteria_for(method)
      criteria.present? && criteria['_id']['$in'].include?(data_type.id.to_s)
    end
  end
end

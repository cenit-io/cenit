module RailsAdmin
  module FiltersHelper

    def update_filters_session
      session[:filters] ||= {}
      session[:filters][@model_name] = nil if params[:all].present?
      session[:filters][@model_name] = params[:filter_token] if params[:filter_token]
    end

    def get_data_type_filter
      if session[:filters] && session[:filters][@model_name]
        filter_token = Cenit::Token.where(token: session[:filters][@model_name]).first
        @data_type_filter = Setup::DataType.where(id: filter_token.data[:data_type_id]).first if filter_token
      end
    end

  end
end


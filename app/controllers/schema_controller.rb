class SchemaController < ApplicationController

  def index
    if (key = params.delete('key')) &&
      (user = User.where(unique_key: key).first) &&
      (Thread.current[:current_account] = user.account) &&
      (schema = Setup::Schema.where(namespace: params[:ns], uri: params[:uri]).first)
      render plain: schema.cenit_ref_schema(service_url: request.base_url + request.path)
    else
      render json: {ns: params[:ns], uri: params[:uri]}, status: 404
    end
  end

end

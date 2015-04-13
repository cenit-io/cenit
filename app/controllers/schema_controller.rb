class SchemaController < ApplicationController

  def index
    puts uri = params[:uri]
    schema = Setup::Schema.where(uri: uri).first
    render plain: schema && schema.cenit_ref_schema
  end
end

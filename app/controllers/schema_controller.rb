class SchemaController < ApplicationController

  def index
    sleep 10
    @schema = Setup::DataType.where(uri: params[:uri]).first

    render plain: @schema
  end
end

class SchemaController < ApplicationController

  def index
    sleep 10
    @schema = Setup::DataType.find_by(:uri => params[:uri]).schema rescue nil

    render plain: @schema
  end
end

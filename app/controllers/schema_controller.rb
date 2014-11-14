class SchemaController < ApplicationController

  def index
    @schema = Setup::XmlSchema.find_by(:uri => params[:uri]).schema rescue nil

    render plain: @schema
  end
end

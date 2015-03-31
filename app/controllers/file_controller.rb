class FileController < ApplicationController

  def index
    if model_desc = params[:model]
      model = Object
      model_desc.split('~').each do |token|
        next unless model
        model = model.const_get(token.camelize) rescue nil
      end
      if model && (record = model.where(id: params[:id]).first) && content = (field = record.try(params[:field])).try(:read)
        send_data content, type: field.file.content_type, disposition: 'inline'
        ok = true
      end
    end
    render plain: 'Not found' unless ok
  end
end

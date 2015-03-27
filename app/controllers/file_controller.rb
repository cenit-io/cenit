class FileController < ApplicationController

  def index

    if model = params[:model].constantize rescue nil
      if record = model.where(id: params[:id]).first
        if content = (field = record.try(params[:field])).try(:read)
          puts field.file.content_type
            send_data content, type: field.file.content_type, disposition: 'inline'
            ok = true
          end
        end
      end

    render plain: 'Not found' unless ok
  end
end

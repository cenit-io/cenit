module Setup
  class ApiSpecImport < Setup::Task
    include Setup::DataUploader
    include Setup::DataIterator
    include ::RailsAdmin::Models::Setup::ApiSpecImportAdmin

    build_in_data_type

    field :base_url, type: String, default: ''

    before_save do
      self.base_url = message[:base_url].to_s
    end

    def decompress_content?
      (i = (name = data.path).rindex('.')) && name.from(i) == '.zip'
    end

    def run(message)
      each_entry do |entry_name, spec|
        url = base_url.blank? ? entry_name : "#{base_url}/#{entry_name}"
        if (api_spec = Setup::ApiSpec.create(url: url, specification: spec)).errors.blank?
          if api_spec.title.blank?
            api_spec.update(title: api_spec.title = entry_name.to_title)
          end
        else
          notify(message: "Error importing entry #{entry_name}: #{api_spec.errors.full_messages.to_sentence}")
        end
      end
    end
    
  end
end

module Setup
  class PullImport < Setup::Task
    include Setup::DataUploader
    include HashField

    build_in_data_type

    hash_field :pull_request, :pulled_request

    def shared_collection
      @shared_collection ||= Setup::CrossSharedCollection.new(pull_data: JSON.parse(self.data.read || {}))
    end

    def run(message)
      if pull_request.present?
        self.pulled_request = Cenit::Actions.pull(shared_collection, pull_request)
        self.pull_request = {}
        {
          fixed_errors: :warning,
          errors: :error
        }.each do |key, type|
          (pulled_request[key] || []).each do |msg|
            notify(message: msg, type: type)
          end
        end
      else
        self.pulled_request = {}
        self.pull_request = Cenit::Actions.pull_request(shared_collection,
                                                        discard_collection: true,
                                                        updated_records_ids: true)
        if shared_collection.pull_parameters.present? ||
          pull_request[:new_records].present? ||
          pull_request[:updated_records].present?
          notify(message: 'Waiting for pull review', type: :notice)
          resume_later
        end
      end
    end
  end
end

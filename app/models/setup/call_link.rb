module Setup
  class CallLink
    include CenitScoped
    include ::RailsAdmin::Models::Setup::CallLinkAdmin

    build_in_data_type.referenced_by(:name)

    field :name, type: String
    belongs_to :link, class_name: Setup::Algorithm.to_s, inverse_of: nil

    embedded_in :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: :call_links

    attr_readonly :name

    validates_presence_of :name

    after_validation :do_link

    def do_link
      if algorithm.name == name
        self.link = algorithm
      else
        self.link = Setup::Algorithm.where(name: name).first
      end if link.blank?
      link
    end
    
  end
end

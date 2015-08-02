module Setup
  class CallLink
    include CenitScoped

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: Symbol
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
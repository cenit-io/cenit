module Setup
  class Algorithm
    include CenitScoped
    include NamespaceNamed

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    field :description, type: String
    embeds_many :parameters, class_name: Setup::AlgorithmParameter.to_s, inverse_of: :algorithm
    field :code, type: String
    embeds_many :call_links, class_name: Setup::CallLink.to_s, inverse_of: :algorithm

    field :gist_visible, type: Boolean
    field :gist_id, type: String, default: nil

    validates_format_of :name, with: /\A[a-z]([a-z]|_|\d)*\Z/

    accepts_nested_attributes_for :parameters, allow_destroy: true
    accepts_nested_attributes_for :call_links, allow_destroy: true

    before_save :validate_code

    before_destroy do
      Cenit.github_client.delete_gist(self.gist_id)
    end

    def validate_code
      if code.blank?
        errors.add(:code, "can't be blank")
      else
        Capataz.rewrite(code, halt_on_error: false, logs: logs = {}, locals: parameters.collect { |p| p.name })
        if logs[:errors].present?
          logs[:errors].each { |msg| errors.add(:code, msg) }
          self.call_links = []
        else
          links = []
          (logs[:self_sends] || []).each do |call_name|
            if (call_link = call_links.where(name: call_name).first)
              links << call_link
            else
              links << Setup::CallLink.new(name: call_name)
            end
          end
          self.call_links = links
          do_link
        end
      end
      res = errors.blank?
      if res
        if self.gist_id
          Cenit.github_client.edit_gist(
            self.gist_id,
            files: {"#{self.namespace} - #{self.name}" => {'content' => self.code}}
          )
        else
          r = Cenit.github_client.create_gist(
            description: self.description,
            public: self.gist_visible,
            files: {"#{self.namespace} - #{self.name}" => {'content' => self.code}}
          )
          self.gist_id = r.attrs[:id]
        end
      end
      res
    end

    def do_link
      call_links.each { |call_link| call_link.do_link }
    end

    attr_accessor :self_linker

    def with_linker(linker)
      self.self_linker = linker
      self
    end

    def run(input)
      input = Cenit::Utility.json_value_of(input)
      input = [input] unless input.is_a?(Array)
      args = {}
      parameters.each { |parameter| args[parameter.name] = input.shift }
      do_link
      Cenit::RubyInterpreter.run(code, args, self_linker: self_linker || self)
    end

    def link?(call_symbol)
      link(call_symbol).present?
    end

    def link(call_symbol)
      if (call_link = call_links.where(name: call_symbol).first)
        call_link.do_link
      else
        nil
      end
    end

    def linker_id
      id.to_s
    end

    def for_each_call(visited = Set.new, &block)
      unless visited.include?(self)
        visited << self
        block.call(self) if block
        call_links.each { |call_link| call_link.link.for_each_call(visited, &block) if call_link.link }
      end
    end
  end
end
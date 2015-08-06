module Setup
  class Algorithm
    include CenitScoped

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: Symbol
    field :description, type: String
    embeds_many :parameters, class_name: Setup::AlgorithmParameter.to_s, inverse_of: :algorithm
    field :code, type: String

    validates_presence_of :name, :code, :description

    accepts_nested_attributes_for :parameters, allow_destroy: true

    def execute(input)
      input = Cenit::Utility.json_value_of(input)
      input = [input] unless input.is_a?(Array)
      args = {}
      parameters.each { |parameter| args[parameter.name] = input.shift }
      Cenit::RubyInterpreter.run(code, args)
    end
    
  end
end
module Setup
  Algorithm.class_eval do
    include RailsAdmin::Models::Setup::AlgorithmAdmin
  end
end

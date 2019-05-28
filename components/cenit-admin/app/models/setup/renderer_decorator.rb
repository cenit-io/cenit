module Setup
  Renderer.class_eval do
    include RailsAdmin::Models::Setup::RendererAdmin
  end
end

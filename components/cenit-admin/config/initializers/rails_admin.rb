if defined? ::RailsAdmin
  Cenit['admin:route:draw:listener'] = ::Cenit::Admin::Engine.to_s
end

module Mongoid
  module Tracer
    Trace.class_eval do
      include RailsAdmin::Models::Mongoid::Tracer::TraceAdmin
    end
  end
end

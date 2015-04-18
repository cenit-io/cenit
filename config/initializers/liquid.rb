
{eval: Cenit::Eval, base64: Cenit::Base64}.each { |key, klass| Liquid::Template.register_tag(key, klass) }
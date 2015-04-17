
{eval: Cenit::Eval, base64: Cenit::Base64, encode: Cenit::Encode}.each { |key, klass| Liquid::Template.register_tag(key, klass) }
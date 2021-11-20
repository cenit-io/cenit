module CorsCheck

  def cors_check
    cors_headers
    render body: nil
  end

  def allow_origin_header
    headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || ::Cenit.homepage
  end

  def cors_headers
    allow_origin_header
    headers['Access-Control-Allow-Credentials'] = 'false'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Accept, Content-Type, Authorization, X-Template-Options, X-Query-Options, X-Query-Selector, X-Digest-Options, X-Parser-Options, X-JSON-Path, X-Record-Id, X-Tenant-Id'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
    headers['Access-Control-Max-Age'] = '1728000'
  end

end
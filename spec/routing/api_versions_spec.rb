require 'rails_helper'

RSpec.describe 'Cenit API versions', type: :routing do
  it 'does not route v1 CRUD, authorization ping, or preflight requests' do
    expect(get: '/api/v1/setup/namespace').not_to be_routable
    expect(post: '/api/v1/auth/ping').not_to be_routable
    expect(options: '/api/v1/setup/namespace').not_to be_routable
  end

  it 'routes the v3 gateway and digest endpoints' do
    expect(get: '/api/v3/setup/connection').to route_to(
      controller: 'api/v3/api', action: 'index', __ns_: 'setup', __model_: 'connection', format: 'json'
    )
    expect(post: '/api/v3/setup/flow/flow-id/digest').to route_to(
      controller: 'api/v3/api', action: 'digest', __ns_: 'setup', __model_: 'flow', __id_: 'flow-id'
    )
  end
end

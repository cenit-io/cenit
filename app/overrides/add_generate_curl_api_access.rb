Deface::Override.new(
    :virtual_path => 'rails_admin/main/show',
    :name => 'add_generate_curl_api_access',
    :insert_after => 'div.fieldset h4',
    :partial => 'rails_admin/curl/show'
)

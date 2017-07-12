module RailsAdmin
  ApplicationHelper.module_eval do

    # parent => :root, :collection, :member
    def menu_for(parent, abstract_model = nil, object = nil, only_icon = false, limit = 0) # perf matters here (no action view trickery)
      actions = actions(parent, abstract_model, object).select { |a| a.http_methods.include?(:get) }
      if parent == :root
        limit = 0
      end
      if (limited = limit > 0)
        count_links = 0
        more_actions_links = []
        current_action = nil
        actions.delete_if { |a| a.action_name == @action.action_name && current_action = a }
        actions.unshift(current_action) if current_action
      end

      actions_links =
        actions.collect do |action|
          menu_item = menu_item(only_icon, action, abstract_model, parent, object)
          if limited
            if count_links < limit
              count_links += 1
              menu_item
            else
              more_actions_links << menu_item
              ''
            end
          else
            menu_item
          end
        end

      if limited
        unless more_actions_links.empty?
          label = 'Actions'
          content =
            %(
              <li class="dropdown">
                <a class="dropdown-toggle" data-toggle="dropdown" href="#">
                  <span>#{label}</span>
                  <b class="caret"></b>
                </a>
                <ul id="more_actions" class="dropdown-menu">
            )
          more_actions_links.unshift(content)
          more_actions_links << '</ul> </li>'
          actions_links+= more_actions_links
        end
      end

      actions_links.join.html_safe
    end

    def menu_item(only_icon, action, abstract_model, parent, object)
      wording = wording_for(:menu, action)
      %(
        <li title="#{wording if only_icon}" rel="#{'tooltip' if only_icon}" class="icon #{action.key}_#{parent}_link #{'active' if current_action?(action, abstract_model)}">
          <a class="#{action.pjax? ? 'pjax' : ''}" href="#{url_for(action: action.action_name, controller: 'rails_admin/main', model_name: abstract_model.try(:to_param), id: (object.try(:persisted?) && object.try(:id) || nil))}">
            <i class="#{(abstract_model && abstract_model.config.send("#{action.key}_link_icon")) || action.link_icon}"></i>
            <span#{only_icon ? " style='display:none'" : ''}>#{wording}</span>
          </a>
        </li>
      )
    end

    def wording_for(label, action = @action, abstract_model = @abstract_model, object = @object)
      model_config = abstract_model.try(:config) || action.bindings[:custom_model_config]
      #Patch
      object = abstract_model && object && object.is_a?(abstract_model.model) ? object : nil rescue nil
      action = RailsAdmin::Config::Actions.find(action.to_sym) if action.is_a?(Symbol) || action.is_a?(String)

      capitalize_first_letter I18n.t(
        "admin.actions.#{action.i18n_key}.#{label}",
        model_label: model_config && model_config.contextualized_label(label),
        model_label_plural: model_config && model_config.contextualized_label_plural(label),
        object_label: model_config && object.try(model_config.object_label_method),
      )
    end

    def linking(model)
      if (account = Account.current) &&
        (abstract_model = RailsAdmin.config(model).abstract_model) &&
        (index_action = RailsAdmin::Config::Actions.find(:index, controller: controller, abstract_model: abstract_model)).try(:authorized?)
        [account, abstract_model, index_action]
      else
        [nil, nil, nil]
      end
    end

    def tasks_link
      _, abstract_model, index_action = linking(Setup::Task)
      return nil unless index_action
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main'), class: 'pjax' do
        html = '<i class="icon-tasks" title="Tasks" rel="tooltip"/></i>'
        #...
        html.html_safe
      end
    end

    def storage_link
      _, abstract_model, index_action = linking(Setup::Storage)
      return nil unless index_action
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main'), class: 'pjax' do
        html = '<i class="icon-hdd" title="Storages" rel="tooltip"/></i>'
        html.html_safe
      end
    end

    def authorizations_link
      _, abstract_model, index_action = linking(Setup::Authorization)
      return nil unless index_action
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main'), class: 'pjax' do
        html = '<i class="icon-check"  title="Authorizations" rel="tooltip"></i>'
        if (unauthorized_count = Setup::Authorization.where(authorized: false).count) > 0
          label_html = <<-HTML
            <b class="label rounded label-xs success up" style='border-radius: 500px;
              position: relative;
              top: -10px;
              min-width: 4px;
              min-height: 4px;
              display: inline-block;
              font-size: 9px;
              background-color: #{Setup::SystemNotification.type_color(:error)}'>#{unauthorized_count}
            </b>
          HTML
          html += label_html
        end
        html.html_safe
      end
    end

    def notifications_links
      account, abstract_model, index_action = linking(Setup::SystemNotification)
      return nil unless index_action
      all_links =[]
      bell_link = link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main'), class: 'pjax' do
        '<i class="icon-bell" title="Notification" rel="tooltip"></i>'.html_safe
      end
      all_links << bell_link
      counters = Hash.new { |h, k| h[k] = 0 }
      Setup::SystemNotification.type_enum.each do |type|
        scope = Setup::SystemNotification.where(type: type)
        if (scope.count > 0)
          meta = account.meta
          if meta.present? && (from_date = meta["#{type.to_s}_notifications_listed_at"])
            scope = scope.where(:created_at.gte => from_date)
          end
          count = scope.count
          if (count > 0)
            counters[type] = count
          end
        end
      end
      counters.each do |type, count|
        color = Setup::SystemNotification.type_color(type)
        a=index_path(model_name: abstract_model.to_param, "type" => type, "model_name" => abstract_model.to_param, "utf8" => "✓", "f" => { "type" => { "60852" => { "v" => type } } })
        counter_links = link_to a, class: 'pjax' do
          link = '<b class="label rounded label-xs up notify-counter-link '+ color + '">' + count.to_s + '</b>'
          link.html_safe
        end
        all_links << counter_links.html_safe
      end
      all_links
    end

    def edit_user_link
      # Patch
      inspecting = false
      account_config = nil
      account_abstract_model = nil
      inspect_action = nil
      if (current_user = _current_user)
        unless (current_account = Account.current_tenant).nil? || current_user.owns?(current_account)
          account_abstract_model = (account_config = RailsAdmin.config(Account)).abstract_model
          inspect_action = RailsAdmin::Config::Actions.find(:inspect, controller: controller, abstract_model: account_abstract_model, object: current_account)
          inspecting = inspect_action.try(:authorized?)
          current_user = current_account.owner
        end
      end
      abstract_model = (user_config = RailsAdmin.config(current_user.class)).abstract_model if current_user
      edit_action = RailsAdmin::Config::Actions.find(:show, controller: controller, abstract_model: abstract_model, object: current_user) if abstract_model
      unless current_user && abstract_model && edit_action
        user_config = account_config
        abstract_model = account_abstract_model
        edit_action = inspect_action
        # current_user = current_account #TODO: review danger assignation
      end
      return nil unless current_user && abstract_model && edit_action
      link = link_to url_for(action: edit_action.action_name, model_name: abstract_model.to_param, id: current_user.id, controller: 'rails_admin/main'), class: 'pjax' do
        html = []
        text = current_user.email
        html << content_tag(:span, text, style: 'padding-right:5px')
        unless inspecting
          if current_user && abstract_model && edit_action
            html << image_tag(current_user.picture_url, alt: '', width: '30px')
          end
        end
        html.join.html_safe
      end
      if inspecting
        link = [link]
        link << link_to(url_for(action: inspect_action.action_name, model_name: account_abstract_model.to_param, id: current_account.id, controller: 'rails_admin/main'), class: 'pjax') do
          '<i class="icon-eye-close" style="color: red"></i>'.html_safe
        end
      end
      link
    end

    def filter_by_token
      filter_token = Cenit::Token.where(token: session[:filters][@model_name]).first if session[:filters][@model_name]
      message = filter_token.data['message'] if filter_token.try(:data)
      if message.is_a?(String)
        delete_filter_url = @action.bindings[:controller].url_for()
        filter = '<p class="filter form-search filter_by_token">'
        filter += '<span class="label label-info form-label">'
        filter += "<a href=\"#{delete_filter_url}?all=yes\">"
        filter += '<i class="icon-trash icon-white"></i></a>'
        filter += "#{message}</span>"
        filter += '</p>'
        filter.html_safe
      end
    end

    def main_navigation
      #Patch
      nodes_stack = RailsAdmin::Config.visible_models(controller: controller) +
        Setup::DataType.where(navigation_link: true).collect { |data_type| RailsAdmin.config(data_type.records_model) }
      node_model_names = nodes_stack.collect { |c| c.abstract_model.model_name }
      if @model_configs
        nodes_stack.each_with_index do |node, index|
          if (model_config = @model_configs[node.abstract_model.model_name])
            nodes_stack[index] = model_config
          end
        end
      end

      i = -1
      mongoff_start_index = nil
      definitions_index = nil
      main_labels = []
      data_type_icons =
        {
          Setup::FileDataType => 'fa fa-file',
          Setup::JsonDataType => 'fa fa-database',
          Setup::CrossSharedCollection => 'fa fa-shopping-cart'
        }
      non_setup_data_type_models =
        [
          Setup::FileDataType,
          Setup::JsonDataType,
          Setup::CrossSharedCollection
        ]
      data_type_models =
        {
          Setup::CenitDataType => main_labels
        }
      non_setup_data_type_models.each { |m| data_type_models[m] = [] }
      nav_groups = nodes_stack.group_by(&:navigation_label)
      ecommerce_models = []
      Cenit.ecommerce_data_types.each do |ns, names|
        names.each do |name|
          if (data_type = Setup::DataType.where(namespace: ns, name: name).first)
            ecommerce_models << data_type.records_model
          end
        end
      end
      ecommerce_models = ecommerce_models.collect { |model| RailsAdmin.config(model) }
      nav_groups['eCommerce'] = ecommerce_models
      ecoindex = nav_groups.size
      nav_groups.each do |navigation_label, nav_nodes|
        ecoindex -= 1
        nav_nodes.group_by do |node|
          if ecoindex == 0
            Setup::CrossSharedCollection
          else
            ((data_type = node.abstract_model.model.try(:data_type)) && data_type.class) || Setup::CenitDataType
          end
        end.each do |data_type_model, nodes|
          name = data_type_model.to_s.split('::').last.underscore
          i += 1
          collapse_id = "main-collapse#{i}"
          if nodes.first.is_a?(RailsAdmin::MongoffModelConfig)
            mongoff_start_index ||= i
          end

          nodes = nodes.select { |n| n.parent.nil? || !n.parent.to_s.in?(node_model_names) } if ecoindex > 0
          li_stack = navigation(nodes_stack, nodes, collapse_id, just_li: ecoindex == 0)

          label = navigation_label || t('admin.misc.navigation')
          if label == 'Definitions'
            definitions_index = main_labels.length
          end
          html_id = "main-#{label.underscore.gsub(' ', '-')}"

          icon = mongoff_start_index.nil? && (((opts = RailsAdmin::Config.navigation_options[label]) && opts[:icon]) || 'fa fa-cube')
          icon =
            case icon
            when Symbol
              render partial: icon.to_s
            when String
              "<i class='#{icon}'></i>"
            else
              nil
            end

          if li_stack.present?
            unless ecoindex == 0
              li_stack = %(<div class='panel-heading'>
              <a data-toggle='collapse' data-parent='##{mongoff_start_index ? "#{name}-collapse" : 'main-accordion'}' href='##{collapse_id}' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>) +
                (icon ? "<span class='nav-icon'>#{icon}</span>" : '') +
                %(<span class='nav-caption'>#{capitalize_first_letter label}</span>
              </a>
            </div>
            #{li_stack})
              unless mongoff_start_index
                li_stack = "<div id='#{html_id}' class='panel panel-default'>#{li_stack}</div>"
              end
            end
            data_type_models[data_type_model] << li_stack
          end
        end
      end
      definitions_index ||= main_labels.length - 1
      i = 1
      non_setup_data_type_models.each do |data_type_model|
        links = data_type_models[data_type_model]
        name = data_type_model.to_s.split('::').last.underscore
        action = name == 'cross_shared_collection' ? :ecommerce_index : :link_data_type
        link_link = link_to url_for(action: action,
                                    controller: 'rails_admin/main',
                                    data_type_model: data_type_model.to_s) do
          %{<span class="nav-caption">#{t("admin.misc.link_#{name}")}</span>
              <span class="nav-icon" style="margin-left: 30px;"/>
                <i class="fa fa-plus"></i>
             </span>}.html_safe
        end
        main_labels.insert definitions_index + i, %(<div id='main-#{name}' class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='#main-accordion' href='##{name}-collapse' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-icon'><i class='#{data_type_icons[data_type_model]}'></i></span>
                <span class='nav-caption'>#{t("admin.misc.main_navigation.#{name}")}</span>
              </a>
            </div>
            <div id='#{name}-collapse' class='nav nav-pills nav-stacked panel-collapse collapse'>
              <li>
                #{link_link}
              </li>
              #{links.collect { |link| data_type_model == Setup::CrossSharedCollection ? link : "<div class='panel panel-default'> #{link} </div>" }.join }
            </div>
          </div>)
      end
      main_labels.join.html_safe
    end

    def navigation(nodes_stack, nodes, html_id, options = {})
      return if nodes.blank?
      i = -1
      nav = nodes.collect do |node|
        i += 1
        stack_id = "#{html_id}-sub#{i}"
        origins =
          if (model=node.abstract_model.model).is_a?(Class) && model < CrossOrigin::Document
            model.origins.join(',')
          else
            ''
          end
        children = nodes_stack.select { |n| n.parent.to_s == node.abstract_model.model_name }
        html =
          if children.present?
            li = %(<div class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='##{html_id}' href='##{stack_id}' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-caption'>#{capitalize_first_letter node.label_navigation}</span>
              </a>
            </div>)
            li + navigation(nodes_stack, children, stack_id) + '</div>'
          else
            model_param = node.abstract_model.to_param
            url = url_for(action: :index, controller: 'rails_admin/main', model_name: model_param)
            nav_icon = node.navigation_icon ? %(<i class="#{node.navigation_icon}"></i>).html_safe : ''
            data = {}
            if model_path = node.abstract_model.api_path
              data[:model] = model_path
              data[:origins] = origins
            end
            content_tag :li, data: data do
              link_to url, class: 'pjax' do
                rc = ''
                rc += "<span class='nav-amount'></span>"
                rc += "<span class='nav-caption'>#{capitalize_first_letter node.label_navigation}</span>"
                rc.html_safe
              end
            end
          end
        if node.abstract_model.model == Setup::CrossSharedCollection
          sub_links = ''
          category_count = 0
          counts =
            begin
              node.abstract_model.counts({ cache: true }, @index_scope = @authorization_adapter && @authorization_adapter.query(:index, node.abstract_model))
            rescue Exception
              { default: -1 }
            end
          model_count =
            if current_user
              counts[:default] || counts.values.inject(0, &:+)
            else
              counts.values.inject(0, &:+)
            end
          Setup::Category.all.each do |cat|
            count = (values = Setup::CrossSharedCollection.where(category_ids: cat.id)).count
            if count > 0
              category_count += count
              message = "<span><em>#{node.label_plural}</em> with category <em>#{cat.title}</em></span>"
              filter_token = Cenit::Token.where('data.category_id' => cat.id).first || Cenit::Token.create(data: { criteria: values.selector, message: message, category_id: cat.id })
              sub_links += content_tag :li do
                sub_link_url = index_path(model_name: node.abstract_model.to_param, filter_token: filter_token.token)
                link_to sub_link_url do
                  rc = ''
                  if model_count > 0
                    rc += "<span class='nav-amount active'>#{count}</span>"
                  end
                  rc += "<span class='nav-caption'>#{cat.title}</span>"
                  rc.html_safe
                end
              end
            end
          end

          show_all_link =
            if category_count < model_count
              content_tag :li do
                link_to index_path(model_name: node.abstract_model.to_param), class: 'pjax' do
                  "<span class='nav-amount active'>#{model_count}</span><span class='nav-caption'>Show All</span>".html_safe
                end
              end
            else
              ''
            end
          remote_shared_collection_link =
            if (action = action(:remote_shared_collection)) && action.visible?
              content_tag :li do
                link_to remote_shared_collection_path, class: 'pjax' do
                  "<span class='nav-caption'>#{t('admin.actions.remote_shared_collection.remote')}</span>".html_safe
                end
              end
            else
              ''
            end
          html = %(<div class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='#none' href='#shared-collapse' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-caption'>#{node.label_plural}</span>
              </a>
            </div>
             <div id='shared-collapse' class='nav nav-pills nav-stacked panel-collapse collapse'>
                #{remote_shared_collection_link}
          #{show_all_link}
          #{sub_links}
            </div>
            </div>)

        end
        if node.abstract_model.model == Setup::ApiSpec
          open_api_directory_link = open_api_directory_nav.html_safe
          html = html + open_api_directory_link
        end
        if node.abstract_model.model == Setup::Renderer &&
          (extensions_list = Setup::Renderer.file_extension_filter_enum).present?
          ext_count = 0
          sub_links = ''
          extensions_list.each do |ext|
            next if ext.blank?
            sub_links += content_tag :li, data: { model: node.abstract_model.to_param, ext: ext, origins: origins } do
              #TODO review and improve the params for the sub_link_url generation and try to show the filter in the view
              filter = { file_extension: { 80082 => { v: ext } } }
              sub_link_url = index_path(model_name: node.abstract_model.to_param, utf8: '✓', f: filter)
              link_to sub_link_url, class: 'pjax' do
                rc = ''
                rc += "<span class='nav-amount'></span>"
                rc += "<span class='nav-caption'>#{ext.upcase}</span>"
                rc.html_safe
                rc.html_safe
              end
            end
          end

          show_all_link =
            if ext_count
              content_tag :li do
                link_to index_path(model_name: node.abstract_model.to_param) do
                  "<span class='nav-amount'></span><span class='nav-caption'>Show All</span>".html_safe
                end
              end
            else
              ''
            end
          html = %(<div class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='#none' href='#renderer-collapse' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-caption'>#{node.label_plural}</span>
              </a>
            </div>
             <div id='renderer-collapse' class='nav nav-pills nav-stacked panel-collapse collapse'>
                #{sub_links}
          #{show_all_link}
            </div>
            </div>)
        end
        html
      end.join
      nav = "<div id='#{html_id}' class='nav nav-pills nav-stacked panel-collapse collapse'>#{nav}</div>" unless options[:just_li]
      nav.html_safe
    end

    def open_api_directory_nav
      sub_links = ''
      category_count = 0
      apis = load_apis_specs_cat_count
      categories_list = apis['categories']
      model_count = apis['total']

      categories_list.each do |cat|
        category_filter_url = open_api_directory_path(query: cat['id'], by_category: true)
        sub_links += content_tag :li do
          sub_link_url = category_filter_url
          link_to sub_link_url, class: 'pjax', title: "#{cat['description']}" do
            rc = ''
            rc += "<span class='nav-amount active'>#{cat['count']}</span>"
            rc += "<span class='nav-caption'>#{cat['title']}</span>"
            rc.html_safe
          end
        end

      end

      show_all_link =
        content_tag :li do
          link_to open_api_directory_path, class: 'pjax' do
            "<span class='nav-amount active'>#{model_count}</span><span class='nav-caption'>Show All</span>".html_safe
          end
        end

      html = %(<div class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='#none' href='#open-api-collapse' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-caption'>#{t('admin.actions.open_api_directory.menu')}</span>
              </a>
            </div>
             <div id='open-api-collapse' class='nav nav-pills nav-stacked panel-collapse collapse'>

      #{show_all_link}
      #{sub_links}
            </div>
            </div>)
    end

    def dashboard_main()
      nodes_stack = @model_configs.values.sort_by(&:weight)
      node_model_names =
        if current_user
          RailsAdmin::Config.visible_models(controller: controller)
        else
          Setup::Models.collect { |m| RailsAdmin::Config.model(m) }.select(&:visible)
        end.collect { |c| c.abstract_model.model_name }

      html_ = "<table class='table table-condensed table-striped .col-sm-6'>" +
        '<thead><tr><th class="shrink"></th><th></th><th class="shrink"></th></tr></thead>' +
        nodes_stack.group_by(&:navigation_label).collect do |navigation_label, nodes|
          nodes = nodes.select { |n| n.parent.nil? || !n.parent.to_s.in?(node_model_names) }
          stack = dashboard_navigation nodes_stack, nodes

          label = navigation_label || t('admin.misc.navigation')

          icon = ((opts = RailsAdmin::Config.navigation_options[label]) && opts[:icon]) || 'fa fa-cube'
          icon =
            case icon
            when Symbol
              render partial: icon.to_s
            else
              "<i class='#{icon}'></i>"
            end

          if stack.present?
            %(
              <tbody><tr><td colspan="3"><h3>
                <span class="nav-icon">#{icon}</span>
                <span class="nav-caption">#{label}</span>
              </h3></td></tr>
            #{stack}
            </tbody>)
          end
        end.join + '</tbody></table>'
      html_.html_safe
    end

    def collections_at_dashboard
      html = ''
      limit = 11
      new_url = rails_admin.new_path(model_name: Setup::Collection.to_s.underscore.gsub('/', '~'))
      new_collection = '<div class="col-xs-6 col-sm-4 col-md-2">
                          <a href="'+new_url+'">
                            <div class="collection">
                              <div class="pic text-center">
                              <h5>'+ t('admin.actions.dashboard.collections.add') +'</h5>
                              <i class="fa fa-plus"></i>
                              </div>
                            </div>
                          </a>
                        </div>'
      if current_user
        # Show user collections
        Setup::Collection.limit(limit).asc(:created_at).each do |c|
          html+= dashboard_collection_view(c)
        end
      else
        rand_ids = Setup::CrossSharedCollection.where(:image.exists => true, installed: true).pluck(:_id).shuffle[0...limit]
        Setup::CrossSharedCollection.where(:_id.in => rand_ids).each do |c|
          html += dashboard_collection_view(c)
        end
      end

      html+= new_collection

      html+=''
      html.html_safe
    end

    def dashboard_collection_view(c)
      has_image = c.image.present?
      css_class = 'img-responsive '+(has_image ? '' : 'no-image')
      image = image_tag has_image ? c.image.versions[:thumb] : 'missing.png', :class => css_class, :alt => c.name, width: '80%', max_height: '80%', margin: '12px'
      url_show = rails_admin.show_path(model_name: c.model_name.to_s.underscore.gsub('/', '~'), id: c.name)
      '<div class="col-xs-6 col-sm-4 col-md-2">
        <a href="'+url_show+'" title="'+ c.name+'">
          <div class="collection">
            <div class="pic text-center">'+image+'
            </div>
          </div>
        </a>
      </div>'
    end

    def dashboard_navigation(nodes_stack, nodes)
      return unless nodes.present?
      i = -1
      ('' +
        nodes.collect do |node|
          i += 1

          children = nodes_stack.select { |n| n.parent.to_s == node.abstract_model.model_name }
          if children.present?
            li = dashboard_navigation nodes_stack, children
          else
            model_param = node.abstract_model.to_param
            url = url_for(action: :index, controller: 'rails_admin/main', model_name: model_param)
            content_tag :tr, data: { model: model_param } do
              rc = '<td>' + link_to(url, class: 'pjax') do
                if current_user
                  # "#{capitalize_first_letter node.label_navigation}"
                  "#{capitalize_first_letter node.abstract_model.config.label_plural}"
                else
                  "#{capitalize_first_letter node.abstract_model.config.label_plural}"
                end
              end
              rc += '</td>'

              counts =
                if current_user
                  node.abstract_model.counts({ cache: true }, @authorization_adapter && @authorization_adapter.query(:index, node.abstract_model))
                else
                  @counts[node.abstract_model.model_name] || { default: 0 }
                end
              model_count = counts[:default] || counts.values.inject(0, &:+)
              pc = percent(model_count, @max)
              indicator = get_indicator(pc)
              anim = animate_width_to(pc)
              menu = menu_for(:collection, node.abstract_model, nil)

              rc += '<td style="overflow:visible">'
              rc += "<div class='progress progress-#{indicator}' style='margin-bottom:0'>"
              rc += "<div class='animate-width-to progress-bar progress-bar-#{indicator}' data-animate-length='#{anim}' data-animate-width-to='#{anim}' style='width:2%'>"
              rc += "#{model_count}"
              rc += '</div>'
              rc += '</div>'
              rc += '<div id="links" class="options-menu">
                     <span aria-haspopup="true" class="btn dropdown-toggle" data-toggle="dropdown" type="button">
                      <i class="fa fa-ellipsis-v"></i>
                     </span>'
              rc += "<ul class='dropdown-menu'>#{menu}</ul>"
              rc += '</div></td>'
              rc.html_safe
            end
          end
        end.join).html_safe
    end

    def found_menu(abstract_model = @abstract_model)
      actions = actions(:bulk_processable, abstract_model)
      return '' if actions.empty?
      label = (abstract_model.try(:config) || action.bindings[:custom_model_config]).contextualized_label_plural
      content_tag :li, class: 'dropdown', style: 'float:right' do
        content_tag(:a, class: 'dropdown-toggle', data: { toggle: 'dropdown' }, href: '#') { '<div class="btn btn-info">'.html_safe + t('admin.misc.found_menu_title').html_safe + label.html_safe + '<b class="caret"></b></div>'.html_safe } +
          content_tag(:ul, class: 'dropdown-menu', style: 'left:auto; right:0;') do
            actions.collect do |action|
              unless action.nil?
                content_tag :li do
                  link_to(wording_for(:menu, action), url_for(action: action.action_name, model_name: abstract_model.to_param, all: true, params: params.except('set').except('page')), class: 'pjax')
                end
              end
            end.join.html_safe
          end
      end.html_safe
    end

    APIS_GURU_FILE_NAME = 'public/apis.guru.list.json'
    APIS_CATEGORIES_COUNT_FILE_NAME = 'public/apis.guru.cat.count.json'

    def load_apis_specs
      file_name = APIS_GURU_FILE_NAME
      if File.exists?(file_name)
        list = File.read(file_name)
      else
        list = Setup::Connection.get('http://api.apis.guru/v2/list.json').submit!
        File.open(file_name, 'w') { |file| file.write(list) }
        File.delete(APIS_CATEGORIES_COUNT_FILE_NAME) if File.exists?(APIS_CATEGORIES_COUNT_FILE_NAME)
      end
      begin
        JSON.parse(list)
      rescue Exception => ex
        fail "invalid JSON content on #{file_name} (#{ex.message})"
      end
    rescue Exception => ex
      flash[:error] = "Unable to retrieve OpenAPI Directory: #{ex.message}"
      {}
    end

    def list_apis
      cat_ids = Set.new
      apis = load_apis_specs
      if (id = params[:id]) && (api = apis[id])
        apis = { id => api }
      end
      apis = apis.collect do |key, api|
        api['id'] = key
        info = api['versions'][api['preferred']]['info'] || {}
        cat_ids.merge(api['categories'] = info['x-apisguru-categories'] || [])
        api
      end
      categories = {}
      Setup::Category.where(:id.in => cat_ids.to_a).each { |category| categories[category.id] = category.to_hash }
      query = params[:query].to_s.downcase.split(' ')
      filter_by_category = params[:by_category].to_b
      if filter_by_category
        apis.select! do |api|
          api['categories'] = api['categories'].collect { |id| categories[id] || { 'id' => id } }
          query.all? do |token|
            api['categories'].any? { |cat| cat['id'].to_s[token] }
          end
        end
      else
        apis.select! do |api|
          info = api['versions'][api['preferred']]['info']
          api['categories'] = api['categories'].collect { |id| categories[id] || { 'id' => id } }
          query.all? do |token|
            api['id'].to_s.downcase[token] ||
              (%w(title description).any? { |entry| info[entry].to_s.downcase[token] }) ||
              (api['categories'].any? { |cat| cat.values.any? { |value| value.to_s[token] } })
          end
        end
      end
      Kaminari.paginate_array(apis).page(params[:page]).per(20)
    end

    def load_apis_specs_cat_count
      file_name = APIS_CATEGORIES_COUNT_FILE_NAME
      if File.exists?(file_name)
        list = File.read(file_name)
      else
        list = count_apis.to_json
        File.open(file_name, 'w') { |file| file.write(list) }
      end
      begin
        JSON.parse(list)
      rescue Exception => ex
        fail "invalid JSON content on #{file_name} (#{ex.message})"
      end
    rescue Exception => ex
      flash[:error] = "Unable to retrieve OpenAPI Category Count: #{ex.message}"
      {}
    end

    def count_apis
      cat_ids = Set.new
      apis = load_apis_specs
      apis = apis.collect do |key, api|
        api['id'] = key
        info = api['versions'][api['preferred']]['info'] || {}
        cat_ids.merge(api['categories'] = info['x-apisguru-categories'] || [])
        api
      end
      categories = {}
      Setup::Category.where(:id.in => cat_ids.to_a).each { |category| categories[category.id] = category.to_hash }
      query = nil
      apis.select! do |api|
        info = api['versions'][api['preferred']]['info']
        api['categories'] = api['categories'].collect { |id| categories[id] || { 'id' => id } }
      end
      cat_list = categories.keys
      categories_list = []
      cat_list.each do |cat|
        categories_list << categories[cat]
      end
      categories_count = []
      categories_list.each do |cat|
        count = (values = apis.select { |c| c['categories'].include?(cat) }).count
        if count > 0
          cat['count'] = count
          categories_count << cat
        end
      end
      { total: apis.count, categories: categories_count }
    end

    def process_context(opts = {})
      if params[:leave_context] || !context_model_scoped?
        session[:context_model_scope] = session[:context_model] = session[:context_id] = nil
      else
        record = opts[:record]
        context_model =
          ((model = opts[:model]) && model.to_s) ||
            (record && record.class.name) ||
            params[:context_model]
        context_id = (record && record.id) || params[:context_id]
        if context_model || context_id
          session[:context_model] = context_model
          session[:context_id] = context_id
          session[:context_model_scope] = @abstract_model.model_name
        end
      end
    end

    def context_model_scoped?
      (cntx_scope = session[:context_model_scope]).nil? ||
        params[:modal] ||
        params[:associated_collection] ||
        params[:contextual_params] ||
        (@abstract_model && @abstract_model.model_name == cntx_scope)
    end

    def get_context_id(context_model = get_context_model)
      ((session[:context_model] == context_model.to_s) && session[:context_id]) || nil
    end

    def get_context_model
      @context_model ||= (cnxt_model = session[:context_model]) && cnxt_model.constantize
    rescue
      nil
    end

    def get_context_record
      @context_record ||= get_context_model.where(id: session[:context_id]).first
    rescue
      nil
    end

    alias_method :rails_admin_breadcrumb, :breadcrumb

    def breadcrumb(action = @action, _acc = [])
      value = rails_admin_breadcrumb(action, _acc)
      if get_context_record
        context_config = RailsAdmin::Config.model(@context_model)
        value = value.to(value.index('<li') - 1) +
          "<li class=\"false\"><a class=\"contextual-record pjax\" href=\"#{index_path(model_name: @abstract_model.to_param, leave_context: true)}\" title='#{t('admin.misc.leave_context', label: (label = wording_for(:breadcrumb, :show, context_config.abstract_model, get_context_record)))}'>#{label}</a></li>" +
          value.from(value.index('</li>') + 5)
      end
      value.html_safe
    end
  end
end

namespace :cenit do
  namespace :admin do
    namespace :app do
      desc "Show identifier and secret of Cenit-Admin build-in-app"
      task :credentials => :environment do
        printf("--------------------------------------------------------------------------------------------------\n")
        printf(" IDENTIFIER AND SECRET OF CENIT-ADMIN APPLICATION\n")
        printf("--------------------------------------------------------------------------------------------------\n")
        Cenit::BuildInApp.where(slug: 'admin').each do |app|
          printf(" IDENTIFIER: %s\n", app.identifier)
          printf(" SECRET:     %s\n", app.secret)
          printf(" CALLBACKS:  %s\n", app.configuration.redirect_uris.join("\n             "))
          printf("--------------------------------------------------------------------------------------------------\n")
        end
      end

      desc "Add new callbacks url to Cenit-Admin build-in-app"
      task :add_callback, [:url] => :environment do |t, args|
        Cenit::BuildInApp.where(slug: 'admin').each do |app|
          app.configuration.redirect_uris << args[:url] unless app.configuration.redirect_uris.include?(args[:url])
          app.save!
          Rake::Task["cenit:admin:app:credentials"].invoke
        end
      end

    end
  end
end

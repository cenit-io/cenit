# this code should be add in lib/tasks/oauth.rake
require 'highline/import'

namespace :admin do
  desc "Create admin username and password"
  task :create => :environment do
    # see last line where we create an admin if there is none, asking for email and password
    
    def prompt_for_admin_password
      if ENV['ADMIN_PASSWORD']
        password = ENV['ADMIN_PASSWORD'].dup
        say "Admin Password #{password}"
      else
        password = ask('Password [cenit123]: ') do |q|
          q.echo = false
          q.validate = /^(|.{5,40})$/
          q.responses[:not_valid] = 'Invalid password. Must be at least 5 characters long.'
          q.whitespace = :strip
        end
        password = 'cenit123' if password.blank?
      end

      password
    end

    def prompt_for_admin_email
      if ENV['ADMIN_EMAIL']
        email = ENV['ADMIN_EMAIL'].dup
        say "Admin User #{email}"
      else
        email = ask('Email [cenit@example.com]: ') do |q|
          q.echo = true
          q.whitespace = :strip
        end
        email = 'cenit@example.com' if email.blank?
      end

      email
    end

    def create_admin_user
      if ENV['AUTO_ACCEPT']
        password = 'cenit123'
        email = 'cenit@example.com'
      else
        puts 'Create the admin user (press enter for defaults).'
        #name = prompt_for_admin_name unless name
        email = prompt_for_admin_email
        password = prompt_for_admin_password
      end
      attributes = {
        :password => password,
        :email => email
      }

      load 'user.rb'

      if User.where(email: email).first
        say "\nWARNING: There is already a user with the email: #{email}, so no account changes were made.  If you wish to create an additional admin user, please run rake admin:create again with a different email.\n\n"
      else
        admin = User.new(attributes)
        if admin.save
          role = Role.where(:name => "super_admin").first_or_create
          admin.roles << role
          admin.save!
          say "Done!"
        else
          say "There was some problems with persisting new admin user:"
        end
      end
    end

    if User.super_admin.empty?
      create_admin_user
    else
      puts 'Admin user has already been previously created.'
      if agree('Would you like to create a new admin user? (yes/no)')
        create_admin_user
      else
        puts 'No admin user created.'
      end
    end
    puts "Done!"
  end
end

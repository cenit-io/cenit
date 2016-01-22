# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:

user = User.create({name: 'admin@cenithub.com', password: 'cenithub123', confirmed_at: Time.now})
roles = Role.create ([{ name: 'admin' }, { name: 'super_admin'}])
user.roles << roles
user.save

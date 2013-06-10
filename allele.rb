# set up the databases
rake "db:create:all"

#  Gems
gem 'pg'
gem 'strong_parameters'
gem 'bootstrap-sass', '~> 2.3.1.3'
gem 'jquery-rails'
gem 'simple_form'
gem 'devise'
gem 'carrierwave'
gem 'mini_magick','~> 3.3'
gem 'fog'
gem 'exception_notification'
gem 'friendly_id'
gem 'premailer-rails'
gem 'nokogiri'

gem_group :development do
  gem 'mail_view'
end

gem_group :test do
  gem 'database_cleaner'
  gem 'turn'
  gem 'capybara'
  gem 'factory_girl_rails'
end

gem_group :development, :test do
  gem 'pry'
  gem 'pry-debugger'
  gem 'pry-remote'
end

# Generators
generate ("simple_form:install --bootstrap")
generate ("devise:install")
generate ("devise User")
generate ("devise:views")

# Routes
route "root to: 'home#index'"

# Create some template files
run "rm README.rdoc"
run "rm public/favicon.ico"
run "rm app/assets/javascripts/application.js"
run "rm app/assets/stylesheets/application.css"
run "rm app/views/layouts/application.html.erb"
create_file 'app/views/home/index.html.erb'

get 'https://raw.github.com/madebymany/allele/master/templates/favicon.ico', "public/favicon.ico"
get 'https://raw.github.com/madebymany/allele/master/templates/README.md', "README.md"
get 'https://raw.github.com/madebymany/allele/master/templates/app/assets/javascripts/application.js', "app/assets/javascripts/application.js"
get 'https://raw.github.com/madebymany/allele/master/templates/app/assets/stylesheets/application.css.scss', "app/assets/stylesheets/application.css.scss"
get 'https://raw.github.com/madebymany/allele/master/templates/app/views/layouts/application.html.erb', "app/views/layouts/application.html.erb"

create_file 'app/controllers/home_controller.rb' do <<-'FILE'
  class HomeController < ApplicationController
    def index
    end
  end
FILE
end

# Tidy up filesystem
run "rm .gitignore"
run "rm -rf doc/"
run "rm -rf vendor/plugins/"
run "cp config/database.yml config/database.example.yml"
run "rm public/index.html"
run "rm app/assets/images/rails.png"

# Create the Git repo
file ".gitignore", <<-END
.DS_Store
/.bundle
/db/*.sqlite3
/log/*.log
/tmp
/config/database.yml
/config/carrierwave.yml
.vimrc
*.sql
*.sql.gz
.DS_Store
.rvmrc
.powrc
public/uploads/*
public/assets
END

git :init
git :add => "."
git :commit => "-a -m 'New application from Allele template'"

# Final migration
rake ("db:migrate")

# Interactive configure
say "\nTime to configure your new app...\n\n"
from_address = ask("Default mailer from address:")
notification_address = ask("Exception notification email recipient:")
say "\nWe're hosting on Heroku, so we need to setup S3 for file storage:\n"
s3_key = ask("S3 key:")
s3_secret = ask("S3 secret:")
s3_bucket = ask("S3 bucket:")

sendgrid_account = yes?("\nUse your own SendGrid account? (yes|no) ")
if sendgrid_account 
  sendgrid_username = ask("SendGrid username:")
  sendgrid_password = ask("SendGrid password:")
end

# Some basic asset and mailer config
application 'config.assets.initialize_on_precompile = false'
gsub_file 'config/initializers/devise.rb', 'please-change-me-at-config-initializers-devise@example.com', from_address
environment "config.action_mailer.default_url_options = { host: 'localhost:3000' }", env: 'development'
environment "ActionMailer::Base.default :from => '#{from_address}'", env: 'development'
environment "ActionMailer::Base.default :from => '#{from_address}'", env: 'production'

# Config for Exception Notifier and SendGrid
environment "config.middleware.use ExceptionNotifier,
     :email_prefix => 'Application Error',
     :sender_address => '#{from_address}',
     :exception_recipients => '#{notification_address}'
    
  ActionMailer::Base.smtp_settings = {
      :address        => 'smtp.sendgrid.net',
      :port           => '587',
      :authentication => :plain,
      :user_name      => ENV['SENDGRID_USERNAME'],
      :password       => ENV['SENDGRID_PASSWORD'],
      :domain         => 'heroku.com',
      :enable_starttls_auto => true
  }", env: 'production'

# Create remote environment
run "heroku create"

# Nasty...
hostname = ask("\nOne second, what did Heroku say your hostname was? No 'http' please: ")
environment "config.action_mailer.default_url_options = { host: '#{hostname}' }", env: 'production'

# Carry on, nothing to see here
say("\nI see, thanks, couldn't make him out.\n")
run "git push heroku master && heroku run rake db:migrate"

# Set some vars for third-party services
run "heroku config:set S3_KEY=#{s3_key} S3_SECRET=#{s3_secret} S3_BUCKET=#{s3_bucket}"
if sendgrid_account
  run "heroku config:set SENDGRID_USERNAME=#{sendgrid_username} SENDGRID_PASSWORD=#{sendgrid_password}"
else
  run "heroku addons:add sendgrid:starter"
end

# Restart, we're done
run "heroku restart"
say "\nDone: Allele application created at #{hostname}\n"

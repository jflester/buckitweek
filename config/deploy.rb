# This defines a deployment "recipe" that you can feed to capistrano
# (http://manuals.rubyonrails.com/read/book/17). It allows you to automate
# (among other things) the deployment of your application.

require 'yaml'

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================
# You must always specify the application and repository for every recipe. The
# repository must be the URL of the repository you want this recipe to
# correspond to. The deploy_to path must be the path on each machine that will
# form the root of the application path.

set :application, "buckitweek"
set :repository,  "git@github.com:mobileAgent/buckitweek.git"
set :branch, "master"
set :repository_cache, "git_master"
set :deploy_via, :remote_cache
set :git_shallow_clone, 1
set :scm_verbose, true

set :server_name, "buckitweek.org"

# =============================================================================
# ROLES
# =============================================================================
# You can define any number of roles, each of which contains any number of
# machines. Roles might include such things as :web, or :app, or :db, defining
# what the purpose of each machine is. You can also specify options that can
# be used to single out a specific subset of boxes in a particular role, like
# :primary => true.

role :web, "#{server_name}"
role :app, "#{server_name}"
role :db,  "#{server_name}", :primary => true

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================
set :deploy_to, "/var/apps/#{application}"
set :user, "buckitweek"         # defaults to the currently logged in user
set :group, "apache"

set :db_username, "bwpro"

# How much to keep on a cleanup task
set :keep_releases, 3

# Web server
set :web_server, "apache2"
set :path_to_web_server, "/etc/httpd"
set :web_server_port, 80

# The Plesk friendly way...
#set :user_http_conf, "/home/httpd/vhosts/#{server_name}/conf"
set :user_http_conf, "#{path_to_web_server}/conf/rails"


# SSH OPTIONS
# =============================================================================
# ssh_options[:keys] = %w(/path/to/my/key /path/to/another/key)
# ssh_options[:port] = 25

# =============================================================================
# TASKS
# =============================================================================
# Define tasks that run on all (or only some) of the machines. You can specify
# a role (or set of roles) that each task should be executed on. You can also
# narrow the set of servers to a subset of a role by specifying options, which
# must match the options given for the servers to select (like :primary => true)


desc "Restarting mod_rails with restart.txt"
task :restart, :roles => :app, :except => { :no_release => true } do
  run "touch #{current_path}/tmp/restart.txt"
end

desc "Tasks before initial setup"
task :before_setup do
  sudo "mkdir -p /var/apps"
  sudo "chown -R #{user}:#{group} /var/apps/"
  sudo "mkdir -p #{path_to_web_server}/conf/rails"
  sudo "mkdir -p /var/log/#{application}"
end

desc "After updating the code populate a new database.yml"
task :after_update_code, :roles => :app do
  buffer = YAML::load_file('config/database.yml');
  # purge unneeded configurations
  buffer.delete('test');
  buffer.delete('development');

  put YAML::dump(buffer),"#{release_path}/config/database.yml",:mode=>0644

  # Clean up tmp and relink to shared for session and cache data
  sudo "rm -rf #{release_path}/tmp" # because it should not be in svn
  run "ln -nfs #{deploy_to}/shared/tmp #{release_path}/tmp"
end

desc "Tasks to execute after initial setup"
task :after_setup do
  # Make shared config dir to hold config files
  run "mkdir -p #{deploy_to}/shared/config"
  # Make shared tmp for sessions
  run "mkdir -p #{deploy_to}/shared/tmp"
  run "mkdir -p #{deploy_to}/shared/tmp/sessions"
  run "mkdir -p #{deploy_to}/shared/tmp/cache"
  run "mkdir -p #{deploy_to}/shared/tmp/sockets"
end

desc "Backup the remote production database"
task :backup, :roles => :db, :only => { :primary => true } do
  filename = "#{application}.dump.#{Time.now.to_i}.sql.bz2"
  file = "/tmp/#{filename}"
  on_rollback { run "rm /tmp/#{filename}" }
  db = YAML::load_file("config/database.yml")
  run "mysqldump -u #{db['production']['username']} --password=#{db['production']['password']} #{db['production']['database']} | bzip2 -c > #{file}"  do |ch, stream, data|
    puts data
  end
  `mkdir -p #{File.dirname(__FILE__)}/../backups/`
  get file, "backups/#{filename}"
  #delete file
  run "rm /tmp/#{filename}"
end

desc "Backup the database before running migrations"
task :before_migrate do 
  backup
end

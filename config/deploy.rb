require 'capistrano'
require "capistrano/ext/multistage"
require "capistrano_colors"

capistrano_color_matchers = [
  { :match => /^\s+$/,       :color => :hide,      :prio => 10 },
  { :match => /^commit/,     :color => :cyan,    :prio => 10 },
]

colorize( capistrano_color_matchers )


class Capistrano::ServerDefinition
  def to_s
    @to_s ||= begin
      s = @options[:alias] || host
      s = "#{user}@#{s}" if user
      s = "#{s}:#{port}" if port && port != 22
      s
    end
  end
end

set :stages, %w[staging production]
set :default_stage, "staging"

set :application, "signup-fu"
set :repository,  "git@github.com:datasektionen/signup-fu.git"
set :scm, :git

set :deploy_to, "/var/rails/#{application}"
set :user, "rails"
set :use_sudo, false
set :ssh_options, {:forward_agent => true}
set :rails_env, "migration"

set :git_enable_submodules, 1

set(:latest_release)  { fetch(:current_path) }
set(:release_path)    { fetch(:current_path) }
set(:current_release) { fetch(:current_path) }

set(:current_revision)  { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:latest_revision)   { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:previous_revision) { capture("cd #{current_path}; git rev-parse --short HEAD@{1}").strip }

role :app, "clusterfluff.ben-and-jerrys.stacken.kth.se", :alias => "clusterfluff"
role :web, "clusterfluff.ben-and-jerrys.stacken.kth.se", :alias => "clusterfluff"
role :db,  "clusterfluff.ben-and-jerrys.stacken.kth.se", :primary => true, :alias => "clusterfluff"

# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

namespace :deploy do

  desc "Deply"
  task :default do
    update
    restart
  end

  desc "Setup a GitHub-style deployment."
  task :setup, :except => {:no_release => true} do
    dirs = [deploy_to, shared_path]
    dirs += shared_children.map { |d| File.join(shared_path, d) }
    run "#{try_sudo} mkdir -p #{dirs.join(' ')} && #{try_sudo} chmod g+w #{dirs.join(' ')}"
    run "git clone #{repository} #{current_path}"
  end
  desc "Update the deployed code."
  task :update_code, :except => { :no_release => true } do
    run "cd #{current_path}; git pull; git reset --hard #{branch}"
    finalize_update
  end
  
  desc "Update the database (overwritten to avoid symlink)"
  task :migrations do
    transaction do
      update_code
    end
    migrate
    restart
  end

  desc "Symlink stuff"
  task :symlink do
    files = %w[database.yml configuration.yml unicorn.rb]
    cmd = files.map {|file| "ln -sf #{shared_path}/config/#{file} #{release_path}/config/#{file}" }.join(" && ")
    run cmd
  end

  task :restart, :except => { :no_release => true } do
    pid = "#{shared_path}/pids/unicorn.pid"
    run "test -e #{pid} && kill `cat #{pid}` || /bin/true"
  end

  desc "Run migrations"
  task :migrate, :except => {:no_release => true} do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} /usr/local/bin/1.9.2_bundle exec rake db:migrate"
  end

  namespace :rollback do
    desc "Moves the repo back to the previous version of HEAD"
    task :repo, :except => { :no_release => true } do
      set :branch, "HEAD@{1}"
      deploy.default
    end
    
    desc "Rewrite reflog so HEAD@{1} will continue to point to at the next previous release."
    task :cleanup, :except => { :no_release => true } do
      run "cd #{current_path}; git reflog delete --rewrite HEAD@{1}; git reflog delete --rewrite HEAD@{1}"
    end
    
    desc "Rolls back to the previously deployed version."
    task :default do
      rollback.repo
      rollback.cleanup
    end
  end
end

namespace :bundler do  
  task :create_symlink, :roles => :app do
    set :bundle_dir, 'vendor/bundle'
    set :shared_bundle_path, File.join(shared_path, 'bundle')

    run " cd #{release_path} && rm -f #{bundle_dir}" # in the event it already exists..?
    run "mkdir -p #{shared_bundle_path} && cd #{release_path} && ln -s #{shared_bundle_path} #{bundle_dir}"
  end

  task :bundle_new_release, :roles => :app do
    bundler.create_symlink
    run "cd #{release_path} ; /usr/local/bin/1.9.2_bundle install --path #{shared_bundle_path} --without development test deploy"
  end
end

namespace :stats do
  desc "print current git revision"
  task :git_revision, :except => {:no_release => true } do
    run "cd #{current_path} && git show --summary"
  end
end


namespace :delayed_job do
  desc "Start delayed_job process"
  task :start, :roles => :app do
    #run "export RAILS_ENV=production; cd #{current_path}; /usr/local/bin/1.9.2_bundle exec ./script/delayed_job start"
  end
 
  desc "Stop delayed_job process"
  task :stop, :roles => :app do
    run "export RAILS_ENV=production; cd #{current_path}; /usr/local/bin/1.9.2_bundle exec ./script/delayed_job stop"
  end
 
  desc "Restart delayed_job process"
  task :restart, :roles => :app do
    #run "export RAILS_ENV=production; cd #{current_path}; /usr/local/bin/1.9.2_bundle exec ./script/delayed_job restart"
  end
end

after "deploy:start", "delayed_job:start"
after "deploy:stop", "delayed_job:stop"
after "deploy:restart", "delayed_job:restart"
after 'deploy:update_code', 'bundler:bundle_new_release'
after "deploy:restart", "stats:git_revision"

def run_rake(cmd)
  run "cd #{current_path}; /usr/local/bin/1.9.2_bundle exec #{rake} #{cmd}"
end

desc "remote console" 
task :console, :roles => :app do
  input = ''
  run "cd #{current_path} && ./script/console #{ENV['RAILS_ENV']}" do |channel, stream, data|
    next if data.chomp == input.chomp || data.chomp == ''
    print data
    channel.send_data(input = $stdin.gets) if data =~ /^(>|\?)>/
  end
end

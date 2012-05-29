require "bundler/capistrano"

set :bundle_flags, "--deployment --quiet --shebang ruby-local-exec"

set :default_environment, {
  'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
}

set :ssh_options, { :forward_agent => true }

default_run_options[:pty] = true

set :application, "lxrats"
set :scm_username, "git"
set :repository, "#{scm_username}@github.com:wdblair/xrats-frontend.git"

set :scm, :git

set :deploy_via, :remote_cache

set :user, "ats"
server "xrats.illtyped.com", :web,:app,:db,:primary => true

set :deploy_to, "/home/ats/lxrats"
set :production_config_path, "#{deploy_to}/config_files"
set :production_repos_path, "#{deploy_to}/code"
set :branch, "master"

set :use_sudo, false

namespace :deploy do
  desc "Drop in the server's config files and repositories."
  task :copy_application_config do 
    run "cp #{production_config_path}/repos.yml #{release_path}/config/repos.yml"
    run "cp #{production_config_path}/ats.yml #{release_path}/config/ats.yml"
    run <<CMD
rm -rf #{release_path}/repos && 
ln -nfs #{production_repos_path}/repos #{release_path}/repos
CMD
    run <<CMD
rm -rf #{release_path}/ats && 
ln -nfs #{production_repos_path}/ats #{release_path}/ats
CMD
  end
  after "deploy:update_code","deploy:copy_application_config"
end

set :unicorn_pid, "#{current_path}/tmp/pids/unicorn.#{application}.pid"
namespace :deploy do
  desc "Restart unicorn"
  task :restart, :except => { :no_release => true } do
    run "if [ -e #{unicorn_pid} ]; then kill -s USR2 `cat #{unicorn_pid}`; fi"
  end

  desc "Start unicorn"
  task :start, :except => { :no_release => true } do
    run "cd #{current_path}; UNICORN_ENV=production bundle exec unicorn -c #{current_path}/config/unicorn.rb -D"
  end

  desc "Stop unicorn"
  task :stop, :except => { :no_release => true } do
    run "if [ -e #{unicorn_pid} ]; then kill -s QUIT `cat #{unicorn_pid}`; fi; rm #{unicorn_pid}"
  end
end

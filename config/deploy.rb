require "bundler/capistrano"

set :bundle_flags, "--deployment --quiet --binstubs --shebang ruby-local-exec"

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

set :use_sudo, false

set :deploy_to, "/home/ats/lxrats"
set :production_config_path, "#{deploy_to}/config_files"
set :production_repos_path, "#{deploy_to}/code"
set :production_shared_path, "#{deploy_to}/shared"
set :branch, "master"

namespace :deploy do
  desc "Drop in the server's config files and repositories."
  task :copy_application_config do 
    run "cp #{production_config_path}/repos.yml #{release_path}/config/repos.yml"
    run "cp #{production_config_path}/ats.yml #{release_path}/config/ats.yml"
    run "cp #{production_config_path}/sphinx.conf #{release_path}/config/sphinx.conf"
    run "cp #{production_config_path}/app.yml #{release_path}/config/app.yml"
    run <<CMD
rm -rf #{release_path}/repos &&
ln -nfs #{production_repos_path}/repos #{release_path}/repos
CMD
    run <<CMD
rm -rf #{release_path}/ats &&
ln -nfs #{production_repos_path}/ats #{release_path}/ats
CMD
    run <<CMD
rm -rf #{release_path}/data &&
ln -nfs #{production_shared_path}/data #{release_path}/data
CMD
    release_name = File.basename(release_path)
    sudo "#{production_shared_path}/setup-atscc-jailed #{release_name}"
  end
  
  after "deploy:update_code", "deploy:copy_application_config"
end

set :unicorn_pid, "#{current_path}/tmp/pids/unicorn.#{application}.pid"
namespace :deploy do
  desc "Restart unicorn"
  task :restart, :except => { :no_release => true } do
    sudo "/etc/init.d/unicorn restart"
  end

  desc "Start unicorn"
  task :start, :except => { :no_release => true } do
    sudo "/etc/init.d/unicorn start"
  end

  desc "Stop unicorn"
  task :stop, :except => { :no_release => true } do
    sudo "/etc/init.d/unicorn stop"
  end
end

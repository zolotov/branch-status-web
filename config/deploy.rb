set :application, "brancher"
set :repository,  "git://github.com/zolotov/branch-status-web.git"

set :scm, :git
set :git_enable_submodules, 1
set :branch, "master"
set :stage, :production
set :runner, "tech"
set :user, "tech"
set :app_server, :passenger
set :domain, "branch.dev"

set :deploy_to, "/var/www/brancher"

role :web, domain
role :app, domain

server "branch.dev", :app, :web

namespace :deploy do
  task :start, :roles => :app do
	run "touch #{current_release}/tmp/restart.txt"
  end

  task :stop, :roles => :app do
	# Do nothing
  end

  desc "Restart Application"
  task :restart, :roles => :app, :except => { :no_release => true } do
	run "touch #{current_release}/tmp/restart.txt"
    # run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

namespace :configuration do
	task :symlink do
		run "ln -s #{deploy_to}/config.yml #{current_release}/config/config.yml"
	end
end

after "deploy", "configuration:symlink"

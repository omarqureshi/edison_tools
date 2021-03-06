# Capistrano tasks that we use in our apps.

Capistrano::Configuration.instance(:must_exist).load do

  namespace :deploy do
    desc "Deploy your application"
    task :default do
      update
      god.restart_unicorn
    end

    desc "Setup your git-based deployment app"
    task :setup, :except => { :no_release => true } do
      dirs = [deploy_to]
      dirs += shared_children.map { |d| File.join(shared_path, d) }
      run "mkdir -p #{dirs.join(' ')} && chmod g+w #{dirs.join(' ')}"
      run "mkdir -p #{shared_path}/log"
      run "mkdir -p #{shared_path}/pids"
      run "mkdir -p #{shared_path}/tmp"
      run "mkdir -p #{shared_path}/tmp/sockets"
      run "git clone -b #{branch} #{repository} #{current_path}"
    end

    task :cold do
      update
      migrate
    end

    task :update do
      transaction do
        update_code
      end
    end

    desc "Update the deployed code."
    task :update_code, :except => { :no_release => true } do
      run "cd #{current_path}; git fetch origin; git reset --hard origin/#{branch}"
      finalize_update
    end

    desc "Update the database (overwritten to avoid symlink)"
    task :migrations do
      transaction do
        update_code
      end
      migrate
      god.restart_unicorn
    end

    task :update_file_server, :roles => :file do
      update_code
    end


    task :finalize_update, :except => { :no_release => true } do
      run "sudo chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

      # mkdir -p is making sure that the directories are there for some SCM's that don't# save empty folders
      run <<-CMD
      rm -rf #{latest_release}/log #{latest_release}/public/system #{latest_release}/tmp/pids &&
      mkdir -p #{latest_release}/public &&
      mkdir -p #{latest_release}/tmp &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/system #{latest_release}/public/system &&
      ln -s #{shared_path}/pids #{latest_release}/tmp/pids &&
      ln -sf #{shared_path}/database.yml #{latest_release}/config/database.yml
    CMD
      if fetch(:normalize_asset_timestamps, true)
        stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
        asset_paths = fetch(:public_children, %w(images stylesheets javascripts)).map { |p| "#{latest_release}/public/#{p}" }.join("")
        run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
      end
    end


    # Managing crontab file manually now on server
    # see schedule.rb for crons

    namespace :web do
      desc "Disables the website by putting the maintenance files live."
      task :disable, :roles => :web do
        on_rollback { run "mv #{disable_path}index.html #{disable_path}index.disabled.html" }
        run "mv #{disable_path}index.disabled.html #{disable_path}index.html"
      end
      desc "Enables the website by disabling the maintenance files."
      task :enable, :roles => :web do
        run "mv #{disable_path}index.html #{disable_path}index.disabled.html"
      end
      desc "Copies your maintenance from public/maintenance to shared/system/maintenance."
      task :update_maintenance_page, :roles => :web do
        run "rm -rf #{shared_path}/system/maintenance/; true"
        run "cp -r #{release_path}/public/maintenance #{shared_path}/system/"
      end
    end


    desc 'Run the migrations under the current stage.'
    task :migrate, :roles => :db, :only => { :primary => true } do
      if exists?(:stage)
        run "cd #{release_path}; bundle exec rake RAILS_ENV=#{stage} db:migrate"
      else
        run "cd #{release_path}; bundle exec rake RAILS_ENV=production db:migrate"
      end
    end

    namespace :rollback do
      desc "Moves the repo back to the previous version of HEAD"
      task :repo, :except => { :no_release => true } do
        set :branch, "HEAD@{1}"
        deploy.default
      end

      desc "Rewrite reflog so HEAD@{1} will continue to point to at the next previous release."
      task :cleanup, :except => { :no_release => true } do
        run "cd #{current_path}; git reflog delete --rewrite HEAD@{1}; git reflog delete --rewrite HEAD@{1}"end

      desc "Rolls back to the previously deployed version."
      task :default do
        rollback.repo
        rollback.cleanup
      end
    end
  end

  namespace :god do
    task :restart_unicorn, :roles => :app do
      sudo "/usr/bin/god restart unicorn"
    end

    desc "Start god"
    task :start, :roles => :app do
      sudo "/etc/init.d/god start"
    end

    desc "Quit god, but not the processes it's monitoring"
    task :stop, :roles => :app do
      begin
        sudo "/etc/init.d/god stop"
      rescue
        puts 'There is no God'
      end
    end

    desc "Describe the status of the running tasks"
    task :status, :roles => :app do
      sudo "/usr/bin/god status"
    end
  end

end

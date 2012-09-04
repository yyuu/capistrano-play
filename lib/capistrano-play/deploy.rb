#  Copyright 2011 Pascal Voitot [@mandubian][pascal.voitot.dev@gmail.com]
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at:
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end

require 'erb'

module Capistrano
  module Play
    def self.extended(configuration)
      configuration.load {
        # without this, there are problems with sudo on remote server
        default_run_options[:pty] = true
        
        namespace(:deploy) {
          task(:start, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("play:start")
          }
        
          task(:restart, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("play:restart")
          }
        
          task(:stop, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("play:stop")
          }
        }
        
        after 'deploy:setup', 'play:setup'
        after 'deploy:finalize_update', 'play:update'
        
        namespace(:play) {
          _cset(:play_version, '1.2.5')
          _cset(:play_major_version) {
            play_version.scan(/\d+/).first.to_i
          }
          _cset(:play_zip_url) {
            "http://download.playframework.org/releases/#{File.basename(play_zip_file)}"
          }
          _cset(:play_preserve_zip, true)
          _cset(:play_zip_file) {
            File.join(shared_path, 'tools', 'play', "play-#{play_version}.zip")
          }
          _cset(:play_path) {
            File.join(shared_path, 'tools', 'play', "play-#{play_version}")
          }
          _cset(:play_bin) {
            File.join(play_path, 'play')
          }
          _cset(:play_cmd) {
            if fetch(:play_java_home, nil)
              "env JAVA_HOME=#{play_java_home} #{play_bin}"
            else
              play_bin
            end
          }
          _cset(:play_daemonize_method, :play)
          _cset(:play_pid_file) {
            fetch(:app_pid, File.join(shared_path, 'pids', 'server.pid')) # for backward compatibility
          }
          _cset(:play_use_precompile, true) # performe precompilation before restarting service if true
        
          _cset(:play_zip_file_local) {
            File.join(File.expand_path('.'), 'tools', 'play', "play-#{play_version}.zip")
          }
          _cset(:play_path_local) {
            File.join(File.expand_path('.'), 'tools', 'play', "play-#{play_version}")
          }
          _cset(:play_bin_local) {
            File.join(play_path_local, 'play')
          }
          _cset(:play_cmd_local) {
            if fetch(:play_java_home_local, nil)
              "env JAVA_HOME=#{play_java_home_local} #{play_bin_local}"
            else
              play_bin_local
            end
          }
          _cset(:play_project_path) {
            release_path
          }
          _cset(:play_project_path_local) {
            File.expand_path('.')
          }
          _cset(:play_target_path) {
            if play_major_version < 2
              File.join(play_project_path, 'precompiled')
            else
              File.join(play_project_path, 'target')
            end
          }
          _cset(:play_target_path_local) {
            if play_major_version < 2
              File.join(play_project_path_local, 'precompiled')
            else
              File.join(play_project_path_local, 'target')
            end
          }
          _cset(:play_dependencies_path_map) {
            if play_major_version < 2
              {
                File.join(play_project_path, 'lib')     => File.join(play_project_path_local, 'lib'),
                File.join(play_project_path, 'modules') => File.join(play_project_path_local, 'modules'),
              }
            else
              {
                play_target_path => play_target_path_local,
              }
            end
          }
          _cset(:play_subcmd_dependencies) {
            if play_major_version < 2
              "dependencies --forProd --sync"
            else
              "dependencies"
            end
          }
          _cset(:play_subcmd_precompile) {
            if play_major_version < 2
              "precompile"
            else
              "compile"
            end
          }
          _cset(:play_precompile_locally, false) # perform precompilation on localhost
        
          desc("install play if needed")
          task(:setup) {
            transaction {
              setup_ivy if fetch(:play_setup_ivy, false)
              install
              setup_locally if play_precompile_locally
            }
            transaction {
              find_and_execute_task("play:daemonize:#{play_daemonize_method}:setup") if play_daemonize_method
            }
          }
        
          task(:setup_locally) {
            transaction {
              setup_ivy_locally if fetch(:play_setup_ivy_locally, false)
              install_locally
            }
          }
        
          _cset(:play_ivy_settings_template, File.join(File.dirname(__FILE__), 'templates', 'ivysettings.erb'))
          _cset(:play_ivy_settings) {
            File.join(capture('echo $HOME').chomp, '.ivy2', 'ivysettings.xml')
          }
          task(:setup_ivy, :roles => :app, :except => { :no_release => true }) {
            tempfile = File.join('/tmp', File.basename(play_ivy_settings))
            on_rollback {
              run("rm -f #{tempfile}")
            }
            template = File.read(play_ivy_settings_template)
            result = ERB.new(template).result(binding)
            run((<<-EOS).gsub(/\s+/, ' '))
              ( test -d #{File.dirname(play_ivy_settings)} || mkdir -p #{File.dirname(play_ivy_settings)} ) &&
              ( test -f #{play_ivy_settings} && mv -f #{play_ivy_settings} #{play_ivy_settings}.orig; true );
            EOS
            put result, tempfile
            run("diff #{play_ivy_settings} #{tempfile} || mv -f #{tempfile} #{play_ivy_settings}")
          }
        
          _cset(:play_ivy_settings_local, File.join(ENV['HOME'], '.ivy2', 'ivysettings.xml'))
          task(:setup_ivy_locally, :except => { :no_release => true }) {
            template = File.read(play_ivy_settings_template)
            result = ERB.new(template).result(binding)
            run_locally((<<-EOS).gsub(/\s+/, ' '))
              ( test -d #{File.dirname(play_ivy_settings_local)} || mkdir -p #{File.dirname(play_ivy_settings_local)} ) &&
              ( test -f #{play_ivy_settings_local} && mv -f #{play_ivy_settings_local} #{play_ivy_settings_local}.orig; true );
            EOS
            File.open(play_ivy_settings_local, 'w') { |fp| fp.write(result) }
          }
        
          task(:install, :roles => :app, :except => { :no_release => true }) {
            temp_zip = File.join('/tmp', File.basename(play_zip_file))
            temp_dir = File.join('/tmp', File.basename(play_zip_file, '.zip'))
            on_rollback {
              files = [ play_path, temp_zip, temp_dir ]
              files << play_zip_file unless play_preserve_zip
              run("#{try_sudo} rm -rf #{files.join(' ')}")
            }
            run("#{try_sudo} rm -f #{play_zip_file}") unless play_preserve_zip
        
            dirs = [ File.dirname(play_zip_file), File.dirname(play_path) ].uniq()
            run((<<-EOS).gsub(/\s+/, ' '))
              if ! test -x #{play_bin}; then
                mkdir -p #{dirs.join(' ')} &&
                ( test -f #{play_zip_file} || ( wget --no-verbose -O #{temp_zip} #{play_zip_url} && #{try_sudo} mv -f #{temp_zip} #{play_zip_file}; true ) ) &&
                ( test -d #{play_path} || ( unzip -q #{play_zip_file} -d #{File.dirname(temp_dir)} && #{try_sudo} mv -f #{temp_dir} #{play_path}; true ) ) &&
                test -x #{play_bin};
              fi;
            EOS
            run("#{try_sudo} rm -f #{play_zip_file}") unless play_preserve_zip
          }

          task(:install_locally, :except => { :no_release => true }) {
            on_rollback {
              files = [ play_path_local, play_zip_file_local ]
              run_locally("rm -rf #{files.join(' ')}")
            }
            dirs = [ File.dirname(play_zip_file_local), File.dirname(play_path_local) ].uniq()
            run_locally((<<-EOS).gsub(/\s+/, ' '))
              if ! test -x #{play_bin_local}; then
                mkdir -p #{dirs.join(' ')} &&
                ( test -f #{play_zip_file_local} || ( wget --no-verbose -O #{play_zip_file_local} #{play_zip_url} ) ) &&
                ( test -d #{play_path_local} || unzip -q #{play_zip_file_local} -d #{File.dirname(play_path_local)} ) &&
                test -x #{play_bin_local};
              fi;
            EOS
          }
        
          namespace(:daemonize) {
            namespace(:play) {
              task(:setup, :roles => :app, :except => { :no_release => true }) {
                # nop
              }
        
              _cset(:play_start_options) {
                options = []
                options << "-Xss2048k"
                options << "--%prod"
                options
              }
              task(:start, :roles => :app, :except => { :no_release => true }) {
                run("rm -f #{play_pid_file}") # FIXME: should check if the pid is active
                play_start_options << "-Dprecompiled=true" if play_use_precompile
                run("cd #{play_project_path} && nohup #{play_cmd} start --pid_file=#{play_pid_file} #{play_start_options.join(' ')}")
              }
        
              task(:stop, :roles => :app, :except => { :no_release => true }) {
                run("cd #{play_project_path} && #{play_cmd} stop --pid_file=#{play_pid_file}")
              }
        
              task(:restart, :roles => :app, :except => { :no_release => true }) {
                stop
                start
              }
        
              task(:status, :roles => :app, :except => { :no_release => true }) {
                run("cd #{play_project_path} && #{play_cmd} status --pid_file=#{play_pid_file}")
              }
            }
        
            namespace(:upstart) {
              _cset(:play_upstart_service) {
                application
              }
              _cset(:play_upstart_config) {
                File.join('/etc', 'init', "#{play_upstart_service}.conf")
              }
              _cset(:play_upstart_config_template, File.join(File.dirname(__FILE__), 'templates', 'upstart.erb'))
              _cset(:play_upstart_options) {
                options = []
                options << "-Xss2048k"
                options << "--%prod"
                options
              }
              _cset(:play_upstart_runner) {
                user
              }
        
              task(:setup, :roles => :app, :except => { :no_release => true }) {
                tempfile = File.join('/tmp', File.basename(play_upstart_config))
                on_rollback {
                  run("rm -f #{tempfile}")
                }
                play_upstart_options << "-Dprecompiled=true" if play_use_precompile
                template = File.read(play_upstart_config_template)
                result = ERB.new(template).result(binding)
                put result, tempfile
                run("diff #{play_upstart_config} #{tempfile} || #{sudo} mv -f #{tempfile} #{play_upstart_config}")
              }
        
              task(:start, :roles => :app, :except => { :no_release => true }) {
                run("#{sudo} service #{play_upstart_service} start")
              }
        
              task(:stop, :roles => :app, :except => { :no_release => true }) {
                run("#{sudo} service #{play_upstart_service} stop")
              }
        
              task(:restart, :roles => :app, :except => { :no_release => true }) {
                run("#{sudo} service #{play_upstart_service} restart || #{sudo} service #{play_upstart_service} start")
              }
        
              task(:status, :roles => :app, :except => { :no_release => true }) {
                run("#{sudo} service #{play_upstart_service} status")
              }
            }
          }
        
          desc("update play runtime environment")
          task(:update, :roles => :app, :except => { :no_release => true }) {
            if play_major_version < 2
              # FIXME: made tmp/ group writable since deploy:finalize_update creates non-group-writable tmp/
              run("#{try_sudo} chmod g+w #{play_project_path}/tmp") if fetch(:group_writable, true)
            end
        
            if play_use_precompile
              if play_precompile_locally
                setup_locally
                transaction {
                  dependencies_locally
                  precompile_locally
                  upload_locally
                }
              else
                dependencies
                precompile
              end
            else
              dependencies
            end
          }
        
          task(:dependencies, :roles => :app, :except => { :no_release => true }) {
            run("cd #{play_project_path} && #{play_cmd} #{play_subcmd_dependencies}")
          }
        
          task(:dependencies_locally, :roles => :app, :except => { :no_release => true }) {
            if dry_run
              logger.info("resolving play dependencies locally: #{play_project_path_local}")
            else
              logger.debug("cd #{play_project_path_local} && #{play_cmd_local} #{play_subcmd_dependencies}")
              abort("error on resolving play dependencies.") unless system("cd #{play_project_path_local} && #{play_cmd_local} #{play_subcmd_dependencies}")
            end
          }
        
          task(:precompile, :roles => :app, :except => { :no_release => true }) {
            run("cd #{play_project_path} && #{play_cmd} #{play_subcmd_precompile}")
          }
        
          task(:precompile_locally, :roles => :app, :except => { :no_release => true }) {
            on_rollback {
              run_locally("cd #{play_project_path_local} && #{play_cmd_local} clean")
            }
            if dry_run
              logger.info("compiling play application locally: #{play_project_path_local}")
            else
              logger.debug("cd #{play_project_path_local} && #{play_cmd_local} #{play_subcmd_precompile}")
              abort("error on resolving play dependencies.") unless system("cd #{play_project_path_local} && #{play_cmd_local} #{play_subcmd_precompile}")
            end
          }
        
          task(:upload_locally, :roles => :app, :except => { :no_release => true }) {
            map = play_dependencies_path_map.merge(play_target_path => play_target_path_local)
            run("mkdir -p #{map.keys.join(' ')}")
            map.map { |dst, src|
              run_locally("cd #{File.dirname(src)} && tar chzf #{src}.tar.gz #{File.basename(src)}") unless dry_run
              upload "#{src}.tar.gz", "#{dst}.tar.gz"
              run("cd #{File.dirname(dst)} && tar xzf #{dst}.tar.gz && rm #{dst}.tar.gz")
            }
            run("chmod -R g+w #{map.keys.join(' ')}") if fetch(:group_writable, true)
          }
        
          desc("start play service")
          task(:start, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("play:daemon:#{play_daemonize_method}:start") if play_daemonize_method
          }
        
          desc("stop play service")
          task(:stop, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("play:daemon:#{play_daemonize_method}:stop") if play_daemonize_method
          }
        
          desc("restart play service")
          task(:restart, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("play:daemon:#{play_daemonize_method}:restart") if play_daemonize_method
          }
        
          desc("view play status")
          task(:status, :roles => :app, :except => { :no_release => true }) {
            find_and_execute_task("play:daemon:#{play_daemonize_method}:status") if play_daemonize_method
          }
        
          desc("view play pid")
          task(:pid, :roles => :app, :except => { :no_release => true }) {
            run("cd #{play_project_path} && #{play_cmd} pid --pid_file=#{play_pid_file}")
          }
        
          desc("view play version")
          task(:version, :roles => :app, :except => { :no_release => true }) {
            run("cd #{play_project_path} && #{play_cmd} version --pid_file=#{play_pid_file}")
          }
        
          desc("view running play apps")
          task(:ps, :roles => :app, :except => { :no_release => true }) {
            run("ps -eaf | grep 'play'")
          }
        
          desc("kill play processes")
          task(:kill, :roles => :app, :except => { :no_release => true }) {
            run("ps -ef | grep 'play' | grep -v 'grep' | awk '{print $2}'| xargs -i kill {} ; echo ''")
          }
        
          desc("view logfiles")
          task(:logs, :roles => :app, :except => { :no_release => true }) {
            run("tail -f #{shared_path}/log/#{application}.log") do |channel, stream, data|
              puts  # for an extra line break before the host name
              puts "#{channel[:host]}: #{data}"
              break if stream == :err
            end
          }
        }
      }
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend(Capistrano::Play)
end

# vim:set ft=ruby :

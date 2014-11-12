################################################################################
# (c) Copyright 2007-2012 Alces Software Ltd & Stephen F Norledge.             #
#                                                                              #
# Alces HPC Software Toolkit                                                   #
#                                                                              #
# This file/package is part of Symphony                                        #
#                                                                              #
# Symphony is free software: you can redistribute it and/or modify it under    #
# the terms of the GNU Affero General Public License as published by the Free  #
# Software Foundation, either version 3 of the License, or (at your option)    #
# any later version.                                                           #
#                                                                              #
# Symphony is distributed in the hope that it will be useful, but WITHOUT      #
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or        #
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License #
# for more details.                                                            #
#                                                                              #
# You should have received a copy of the GNU Affero General Public License     #
# along with Symphony.  If not, see <http://www.gnu.org/licenses/>.            #
#                                                                              #
# For more information on the Symphony Toolkit, please visit:                  #
# https://github.com/alces-software/symphony                                       #
#                                                                              #
################################################################################
require 'alces/tools/cli'
require 'alces/stack'
require 'alces/stack/repo/manager'
require 'alces/stack/repo/yum_configurator'

module Alces
  module Stack
    module Repo
      class CLI
        include Alces::Tools::CLI
        
        configfilename 'repomanager.yml'
        
        VALID_COMMANDS=['list','add','remove','import','export','update','enable','disable','localize','updatecheck','init']
        
        log_to File.join(Alces::Stack.config.log_root,'alces-repo.log')

        root_only
        name ::File::basename(__FILE__)
        description  "Manage YUM Repositories"

        option :command, {
          description: "Specify Command [#{VALID_COMMANDS.join(",")}]",
          short: '-c',
          long: '--command',
          default: 'list',
          required: true,
          included_in: VALID_COMMANDS
        }

        option :name, {
          description: "Specify repo Name",
          short: "-n",
          long: "--name",
          required: true
        }

        option :initfile, {
          description: "Specify init file for init command",
          short: "-i",
          long: "--initfile",
          required: true
        }
        
        def validate_initfile?
          ['init'].include?(command.downcase)
        end

        def validate_name?
          ['add','remove','import','export','update','enable','disable'].include?(command.downcase)
        end

        option :priority, {
          description: "Specify priority",
          short: "-p",
          long: "--priority",
          default: 99,
        }
        
        option :url, {
          description: "Specify base URL",
          short: "-u",
          long: "--url",
          required: true
        }

        def validate_url?
          command.downcase == 'add'
        end
        
        option :nicename, {
          description: "Specify nice name",
          short: "-m",
          long: "--nicename",
        }
        
        option :gpgkey, {
          description: "Specify GPG key",
          short: "-k",
          long: "--gpgkey",
        }
        
        def execute
          case command
          when 'list'
            do_list
          when 'add'
            do_add(name,url,priority,nicename,gpgkey)
          when 'remove'
            do_remove(name)
          when 'import'
            do_import(name)
          when 'enable'
            do_enable(name)
          when 'disable'
            do_disable(name)
          when 'localize'
            do_localize
          when 'init'
            do_init(initfile)
          when 'export'
            do_export(name)
          when 'update'
            do_update(name)
          when 'updatecheck'
            do_updatecheck(name)
          end
        end
        
        private
        
        def repomanager
          @rm ||= ( 
                   rm=Manager::new
                   rm.local_repo_path=config['local_repo_path']
                   rm.local_repo_url=config['local_repo_url']
                   rm.yum_config_path=config['yum_config_path']
                   rm
                   )
        end
        
        def do_list
          if repomanager.reponames.empty?
            puts "No repos!"
          else
            puts "Repositories:"
            repomanager.reponames.each do |repo|
              puts "================================================================================"
              puts repo
              puts "================================================================================"
              puts
            end
          end
        end
        
        def do_add(name,url,priority=nil,nicename=nil,gpgkey=nil)
          puts "Adding repo: #{name}"
          repomanager.add_repo(name,url,priority,nicename,gpgkey)
        end
        
        def do_remove(name)
          puts "Removing repo: #{name}"
          repomanager.remove_repo(name)
        end
        
        def do_enable(name)
          puts "Activating repo: #{name}"
          repomanager.enable_repo(name)
          inform_yum
        end
        
        def do_disable(name)
          puts "Deactivating repo: #{name}"
          repomanager.disable_repo(name)
          inform_yum
        end
        
        def do_import(name)
          puts "Importing repo: #{name}"
          puts "Please Wait.."
          repomanager.import_repo(name)
          inform_yum
        end
        
        def do_export(name)
          puts "Exporting repo: #{name}"
          repomanager.export_repo(name)
          inform_yum
        end

        def do_localize
          puts "Localising YUM configuration"
          repomanager.localize
          inform_yum
        end
        
        def do_init(basefile)
          puts "Performing YUM reset to defaults based on '#{basefile}'"
          repomanager.init(basefile)
          inform_yum
        end
        
        def do_update(name)
          puts "Updating repo: #{name}"
          puts "Please Wait.."
          repomanager.update_repo(name)
          inform_yum
        end
        
        def do_updatecheck(name)
          puts "Running Update Check: #{name}"
          puts "Please Wait.."
          puts repomanager.updatecheck_repo(name)
        end
        
        private
        
        def inform_yum
          YUMConfigurator.new(config['yum_config_path']).write_alces_repos(repomanager)
        end        
      end
    end
  end
end

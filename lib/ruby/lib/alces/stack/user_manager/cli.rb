################################################################################
# (c) Copyright 2007-2011 Alces Software Ltd & Stephen F Norledge.             #
#                                                                              #
# ALCES SOFTWARE HPC CLUSTER MANAGEMENT SUITE                                  #
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
# http://www.alces-software.org/symphony                                       #
#                                                                              #
################################################################################
require 'yaml'
require 'alces/stack/user_manager/configuration'
require 'alces/tools/cli'
require 'alces/tools/config'
require 'alces/stack'

module Alces
  module Stack
    module UserManager
      class CLI
        VALID_USER_TYPES = ['LOCAL','CLUSTER','COBBLER','NAGIOS','MYSQL']
        VALID_ACTIONS = ['CREATE','DELETE','PASSWD']
        VALID_BACKENDS = ['NIS','LDAP']
        
        include Alces::Tools::CLI
        include Alces::Tools::Config
        
        root_only
        name 'alces-user-manager'
        description 'Cluster aware users management'
        log_to File.join(Alces::Stack.config.log_root,'alces-user-manager.log')

        option :type, {
          description: "Specify user type #{VALID_USER_TYPES}",
          short: '-t',
          long: '--type',
          default: 'CLUSTER',
          required: true,
          included_in: VALID_USER_TYPES
        }
        option :action, {
          description: "Specify an action to perform #{VALID_ACTIONS}",
          short: '-a',
          long: '--action',
          default: 'CREATE',
          required: true,
          included_in: VALID_ACTIONS
        }
        option :backend, {
          description: "Specify cluster user backend type #{VALID_BACKENDS}",
          short: '-b',
          long: '--backend',
          required: true,
          included_in: VALID_BACKENDS,
          default: Proc.new { config['default_backend'].to_s }
        }
        option :username, {
          description: "Specify a username",
          short: '-u',
          long: '--username',
          required: true
        }
        option :parameters, {
          description: "Specify additional, comma-separated, (type-specific) parameters (key=value)",
          short: '-p',
          long: '--parameters'
        }
        option :homedir, {
          description: "Specify user home dir (LOCAL,CLUSTER only)",
          short: '-d',
          long: '--homedir',
          required: true,
          validate_when: :local_or_cluster?,
          default: :username
        }
        option :shell, {
          description: "Specify user shell (LOCAL,CLUSTER only)",
          short: '-s',
          long: '--shell',
          required: true,
          validate_when: :local_or_cluster?,
          default: Proc.new { config['default_shell'] }
        }
        option :comment, {
          description: "Specify user comment (LOCAL,CLUSTER only)",
          short: '-c',
          long: '--comment',
          default: Proc.new { config['default_comment'] }
        }
        
        class << self
          def config
            begin
              configfile=Alces::Tools::Config::find('usermanager.yml')
              @config ||= YAML::load_file(configfile)
              raise unless @config.kind_of? Hash
              @config
            rescue
              raise ConfigFileException, "Problem loading configuration file - #{configfile}"
            end
          end
        end

        def local_or_cluster?
          ['LOCAL','CLUSTER'].include?(type.upcase)
        end
        
        def user_type(&block)
          klass = case type
                  when /CLUSTER/i
                    case backend
                    when /NIS/i
                      Alces::Stack::UserManager::Types::NIS
                    when /LDAP/i
                      Alces::Stack::UserManager::Types::LDAP
                    end
                  when /LOCAL/i
                    Alces::Stack::UserManager::Types::Local
                  when /COBBLER/i
                    Alces::Stack::UserManager::Types::Cobbler
                  when /NAGIOS/i
                    Alces::Stack::UserManager::Types::Nagios
                  when /MYSQL/i
                    Alces::Stack::UserManager::Types::Mysql
                  end
          raise "Unable to determine user type" if klass.nil?
          block.call(klass.new(Configuration.new(username, user_homedir, shell, comment, self.class.config, parameters)))
        end

        def user_homedir
          case homedir
          when :username
            File.join((config['default_home'] || 'home'),username.to_s)
          else
            homedir
          end
        end

        def execute
          user_type do |u|
            case action
            when /CREATE/i, /DELETE/i, /PASSWD/i
              u.send(action.downcase)
            else
              raise "Unable to determine action"
            end
          end
        end
      end
    end
  end
end

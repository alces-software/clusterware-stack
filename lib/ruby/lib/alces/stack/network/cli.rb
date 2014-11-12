################################################################################
# (c) Copyright 2007-2011 Alces Software Ltd & Stephen F Norledge.             #
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
# http://www.alces-software.org/symphony                                       #
#                                                                              #
################################################################################
require 'alces/stack'
require 'alces/stack/network/configuration'
require 'alces/stack/network/configurator'
require 'alces/tools/cli'
require 'alces/stack/profile'

module Alces
  module Stack
    module Network
      class CLI
        VALID_COMMANDS = ['CONFIGURE']

        include Alces::Tools::CLI

        root_only
        name 'alces-network'
        description 'Configure systems network interfaces using Infrastructure data'
        log_to File.join(Alces::Stack.config.log_root,'alces-network.log')

        option :command,
               "Specify command #{VALID_COMMANDS}",
               '--command', '-c',
               default: 'CONFIGURE',
               required: true,
               included_in: VALID_COMMANDS

        option :root,
               'Specify root path for config installation',
               '--root', '-r',
               default: '/',
               required: true

        option :interfaces, 
               'Specify interface names, comma separated - eg eth0,eth1,ib0',
               '--interfaces', '-i',
               default: 'all',
               required: true

        option :profile, {
          description: "Specify a profile name",
          short: "-p",
          long: "--profile",
          required: true,
          condition: lambda { |profile| Alces::Stack::Profile::ProfileManager.has_profile?   (profile) }
        }

        option :member, {
          description: "Specify a Member index",
          short: "-m",
          long: "--member",
          required: true,
        }

        flag   :livemacs,
               'Attempt to gather live mac entries into output files (where possible)',
               '--livemacs'

        option :forcedhcp,
               'Force listed interface names to use DHCP, comma separated',
               '--forcedhcp'

        option :forcenoboot,
               'Force listed interface names to not start on boot, comma separated',
               '--forcenoboot'

        def validate_options
          super
        end

        def execute
          case command
          when /CONFIGURE/i
            p=Alces::Stack::Profile::ProfileManager.profile(profile)
            if member =~ /^LOCAL/i
              m=p.localmember
            else
              m=p.member(member)
            end
            cfg = Configuration.new(root, m, interfaces, livemacs, forcedhcp, forcenoboot)
            Alces::Stack::Network::Configurator.configure(cfg)
          else
            raise "Unable to determine action"
          end
        end
      end
    end
  end
end

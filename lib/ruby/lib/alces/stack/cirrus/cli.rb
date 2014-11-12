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
require 'alces/stack/cirrus/duplicator'
require 'alces/stack/cirrus/nic_manager'
require 'alces/stack/cirrus/lister'
require 'alces/stack/cirrus/deleter'
require 'alces/stack'

module Alces
  module Stack
    module Cirrus
      class CLI
        include Alces::Tools::CLI

        root_only

        name 'alces-cirrus'
        description "Perform modifications to the infrastructure database"
        log_to File.join(Alces::Stack.config.log_root,'alces-cirrus.log')

        option :database,
               'Specify path to infrastructure database',
               '--database', '-d',
               '/opt/cirrus.sqlite3',
               file_exists: true

        flag :noninteractive,
             'Do not prompt for any confirmations (DANGEROUS)',
             '--yes'

        class << self
          def cli_usage
            "#{super} <command>"
          end
          
          def usage_text
            t = super 
            t << <<EOF


COMMANDS

   delete <identifier>|+<hostname> [<identifier>|+<hostname>...]
     Delete one or more nodes identified by <identifier> or, if
     prefixed with a '+' character, the hostname <hostname>.  Will
     prompt for confirmation before deletion occurs unless the --yes
     flag has been specified.

   duplicate <identifier>|+<hostname> [<count>|<target>]
     Duplicate one or more nodes from the node identified by
     <identifier> or, if prefixed with a '+' character, the hostname
     <hostname>.  Specify an integer <count> to automatically
     incrememnt node identifiers (defaults to 1).  Spcifying a string
     <target> will duplicate a single node and set <target> as the
     identifier for the new node.

   list
     Display node identifiers, groups, hostnames and primary MAC
     addresses currently maintained within the infrastructure
     database.

   setmac <identifier>|+<hostname> <hwaddr> [<interface>]
     For the node identified by <identifier> or, if prefixed with a
     '+' character, the hostname <hostname>, set the MAC address of
     <interface> to <hwaddr> (defaults to the primary interface).

EOF
          end
        end

        def configure_cirrus!
          info "Configuring Cirrus with #{database}"
          Alces::Cirrus.setup do |config|
            config.database_path = database
          end
        end
        
        def execute
          configure_cirrus!
          if command = ARGV.shift
            case command.downcase
            when 'duplicate'
              usage_and_exit if ARGV.empty?
              Duplicator.duplicate(*ARGV)
            when 'setmac'
              usage_and_exit if ARGV.length < 2
              NicManager.setmac(*ARGV)
            when 'delete'
              usage_and_exit if ARGV.empty?
              Deleter.delete(ARGV, force: noninteractive)
            when 'list'
              Lister.execute
            else
              usage_and_exit
            end
          else
            usage
          end
        end

        def usage_and_exit(exit_value = 1)
          usage
          raise 'Invalid command or options specified'
        end
      end
    end
  end
end

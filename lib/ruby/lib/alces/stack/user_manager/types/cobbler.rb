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
require 'alces/stack/user_manager/types/base'

module Alces
  module Stack
    module UserManager
      module Types
        class Cobbler < Base
          COBBLER_OWNER='apache'
          COBBLER_GROUP='apache'
          COBBLER_MOD='600'
          DIGEST_CMD = <<EOT
touch /etc/cobbler/users.digest && \
  chown #{COBBLER_OWNER}:#{COBBLER_GROUP} /etc/cobbler/users.digest && \
  chmod #{COBBLER_MOD} /etc/cobbler/users.digest && \
  /usr/bin/htdigest /etc/cobbler/users.digest Cobbler %s
EOT

          def create
            statusly("Creating Cobbler User", "Failed to add cobbler user #{username}") do
              run_bash(digest_command, pty: true)
            end
          end

          def passwd
            statusly("Setting Cobbler User password", "Failed to set password for cobbler user #{username}") do
              run_bash(digest_command, pty: true)
            end
          end

          private
          def digest_command
            DIGEST_CMD % username
          end
        end
      end
    end
  end
end

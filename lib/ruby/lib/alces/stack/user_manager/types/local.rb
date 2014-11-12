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
require 'alces/tools/core_ext/object/blank'

module Alces
  module Stack
    module UserManager
      module Types
        class Local < Base
          def create
            group = 'users'
            cmd = %W(/usr/sbin/useradd -m -d #{home} -s #{shell} -g #{group})
            cmd += %W(-c #{comment}) unless comment.blank?
            cmd << username
            statusly("Creating user", "Failed to add user #{username}") do
              run(cmd)
            end
            passwd
          end

          def delete
            statusly("Deleting user", "Failed to delete user #{username}") do
              run(['/usr/sbin/userdel',username])
            end
          end

          def passwd
            statusly("Setting password", "Failed to set user password for #{username}") do
              run(['/usr/bin/passwd',username], pty: true)
            end
          end
        end
      end
    end
  end
end

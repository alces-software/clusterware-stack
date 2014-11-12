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
        class LDAP < Base
          def create
            #Comments not supported in LDAP
            #ldap_comment = "UserComment: #{comment}\n" unless comment.blank?
            with_temp_file(<<LDIF) do |path|
dn: uid=#{username},ou=People,#{ldap_domain}
uid: #{username}
cn: #{username}
objectClass: account
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
loginShell: #{shell}
uidNumber: #{uid}
gidNumber: 5000
homeDirectory: #{home}
LDIF
              cmd = %W(ldapadd -x -D #{ldap_manager} -W -f #{path})
              statusly("Inserting new user into LDAP database", 
                       "Failed to insert new user '#{username}' into LDAP database") do
                run(cmd, pty: true)
              end
            end
            passwd
          end

          def delete
            cmd = %W(ldapdelete -x -D #{ldap_manager} -W #{ldap_user})
            statusly("Deleting user from LDAP database",
                     "Failed to delete user '#{username}' from LDAP database") do
              run(cmd, pty: true)
            end
          end

          def passwd
            cmd = %W(ldappasswd -x -D #{ldap_manager} -W #{ldap_user} -S)
            statusly("Setting user password in LDAP database",
                     "Failed to update user passwd '#{username}' in LDAP database") do
              run(cmd, pty: true)
            end
          end

          private
          def ldap_user
            "uid=#{username},ou=People,#{ldap_domain}"
          end

          def uid
            r = statusly("Collecting LDAP userids", "Failed to collect user ids") do
              run_bash("ldapsearch -x '(objectclass=account)' | grep uidNumber | awk '{ print $2 }' | sort")
            end
            begin
              uid = r.stdout.split.last.to_i + 1
              uid = 5000 if uid == 1 #no ldap users exist yet
              raise unless uid >= 5000
              #check userid does not exist on the system, increment upto a max of 10 times to find an available one
              10.times do |t|
                r = statusly("UID '#{uid}' in use, looking for another one!") do
                  run_bash("if ! getent passwd | cut -d ':' -f 3 | grep -e '^#{uid}$'; then true; else false; fi")
                end
                break unless r.fail?
                uid += 1
              end
              raise if r.fail?
            rescue
              raise UserCommandFailure, "Failed to calculate next available UID"
            end
            uid
          end
        end
      end 
    end
  end
end

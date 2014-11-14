################################################################################
# (c) Copyright 2012 Alces Software Ltd & Stephen F Norledge.                  #
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
# https://github.com/alces-software/symphony                                       #
#                                                                              #
################################################################################
require 'alces/stack/user_manager/types/base'
require 'highline/import'

module Alces
  module Stack
    module UserManager
      module Types
        class Mysql < Base
          PASSWORD_FILE = '/opt/clusterware/etc/personality/passwords.yml'

          CREATE_USER_4_x = <<-SQL
            GRANT USAGE ON *.* TO '%<username>s'@'localhost' IDENTIFIED BY '%<password>s';
            GRANT USAGE ON *.* TO '%<username>s'@'%%' IDENTIFIED BY '%<password>s';
          SQL

          CREATE_USER = <<-SQL
            CREATE USER '%<username>s'@'localhost' IDENTIFIED BY '%<password>s';
            CREATE USER '%<username>s'@'%%' IDENTIFIED BY '%<password>s';
          SQL

          DROP_USER = <<-SQL
            DROP USER '%<username>s'@'localhost';
            DROP USER '%<username>s'@'%%';
          SQL

          MODIFY_PASSWORD = <<-SQL
            SET PASSWORD FOR '%<username>s'@'localhost' = PASSWORD('%<password>s');
            SET PASSWORD FOR '%<username>s'@'%%' = PASSWORD('%<password>s');
          SQL

          GRANTS = {
            none: '',
            admin: <<-SQL,
              GRANT ALL PRIVILEGES ON *.* TO '%<username>s'@'localhost' WITH GRANT OPTION;
              GRANT ALL PRIVILEGES ON *.* TO '%<username>s'@'%%' WITH GRANT OPTION;
            SQL
            dbadmin: <<-SQL,
              GRANT ALL PRIVILEGES ON %<database>s.* TO '%<username>s'@'localhost';
              GRANT ALL PRIVILEGES ON %<database>s.* TO '%<username>s'@'%%';
            SQL
            dbreader: <<-SQL,
              GRANT SELECT ON %<database>s.* TO '%<username>s'@'localhost';
              GRANT SELECT ON %<database>s.* TO '%<username>s'@'%%';
            SQL
            dbuser: <<-SQL,
              GRANT SELECT,INSERT,UPDATE,DELETE ON %<database>s.* TO '%<username>s'@'localhost';
              GRANT SELECT,INSERT,UPDATE,DELETE ON %<database>s.* TO '%<username>s'@'%%';
            SQL
            restricted_admin: <<-SQL
              GRANT ALL PRIVILEGES ON `%<prefix>s%%`.* TO '%<username>s'@'localhost';
              GRANT ALL PRIVILEGES ON `%<prefix>s%%`.* TO '%<username>s'@'%%';
            SQL
          }

          def create
            assert_no_quote!('username',username)
            verify_parameters!
            pwd = password
            assert_no_quote!('password',pwd)
            statusly("Creating MySQL user", "Failed to add MySQL user #{username}") do
              sql = CREATE_USER % {username: username, password: pwd}
              run(mysql_command, stdin: sql)
            end
            grant unless usertype == :none
          end

          def delete
            assert_no_quote!('username',username)
            fail("Sorry, dropping the 'admin' user is forbidden.",nil) if username == 'admin'
            statusly("Dropping MySQL user", "Failed to drop MySQL user #{username}") do
              sql = DROP_USER % {username: username}
              run(mysql_command, stdin: sql)
            end
          end

          def passwd
            assert_no_quote!('username',username)
            pwd = password
            assert_no_quote!('password',pwd)
            statusly("Setting MySQL user password", "Failed to set password for MySQL user #{username}") do
              sql = MODIFY_PASSWORD % {username: username, password: pwd}
              run(mysql_command, stdin: sql)
            end
          end

          private
          def assert_no_quote!(name, value)
            fail("Invalid character \"'\" found in #{name}: #{value}", nil) if value =~ /'/
          end

          def verify_parameters!
            fail("No such usertype '#{usertype}'; please supply usertype=<type> as a parameter, where <type> is one of: #{GRANTS.keys.join(', ')}",nil) unless GRANTS.key?(usertype)
            case usertype
            when :dbadmin, :dbreader, :dbuser
              fail("No database specified, please supply database=<database name> as a parameter.", nil) if database.nil?
              assert_no_quote!('database',database)
            when :restricted_admin
              fail("No prefix specified, please supply prefix=<prefix> as a parameter.", nil) if prefix.nil?
              assert_no_quote!('prefix',prefix)
            end
          end

          def grant
            statusly("Granting '#{usertype}' to MySQL user '#{username}'", "Failed to grant '#{usertype}' to MySQL user '#{username}'") do
              sql = GRANTS[usertype] % {
                username: username, 
                database: database,
                prefix: prefix
              }
              run(mysql_command, stdin: sql)
            end
          end

          def database; super rescue nil; end
          def prefix; super rescue nil; end
          def usertype
            @usertype ||= (super.downcase.to_sym)
          rescue
            :unknown
          end

          def password
            ask("Enter new password for #{username}: ") { |q| q.echo = false }
          end

          def mysql_command
            @mysql_command ||= [].tap do |a|
              a << 'mysql'
              a << "-u#{ENV['ALCES_USER_MANAGER_MYSQL_USER'] || 'admin'}"
              a << "-p#{admin_password}" unless admin_password.nil?
              a << 'mysql'
            end
          end

          def admin_password
            @admin_password ||= (
                                 if ENV['ALCES_USER_MANAGER_MYSQL_PASSWORD'] == '*'
                                   nil
                                 elsif ENV['ALCES_USER_MANAGER_MYSQL_PASSWORD']
                                   ENV['ALCES_USER_MANAGER_MYSQL_PASSWORD']
                                 else
                                   YAML.load_file(PASSWORD_FILE)[:admin] rescue nil
                                 end
                                )
          end
        end
      end
    end
  end
end

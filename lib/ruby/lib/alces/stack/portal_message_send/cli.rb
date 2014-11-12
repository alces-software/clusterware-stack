################################################################################
# (c) Copyright 2013 Alces Software Ltd & Stephen F Norledge.                  #
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
require 'alces/stack'
require 'alces/tools/cli'
require 'alces/tools/hashing'

require 'alces/stack/portal_message_send/sender'

module Alces
  module Stack
    module PortalMessage
      class CLI
        include Alces::Tools::CLI

        name 'portal-message-send'
        description 'Send a message to a Alces Portal'

        class << self
          def cli_usage
            super
            "#{super} <MESSAGE> [KEY=VALUE]"
          end
          
          def usage_text
            t = super 
            t << <<EOF


MESSAGE

   The name of the message to send.

KEY=VALUE

   Each key value pair is included in the message body. Multiple key value
   pairs may be provided but the keys should be unique.

EOF
          end
        end

        def execute
          if ARGV.empty?
            usage
          else

            message_type = ARGV[0]
            ARGV.shift

            data = {}
            ARGV.each do |a|
              key, value = a.split('=')
              data[key] = value
            end

            user_token = load_user_token

            Alces::Stack::PortalMessage::Sender.new(config.merge(auth_token: user_token)).send(message_type, data)
          end
        end

        private

        def load_user_token
          data_home = ENV['XDG_DATA_HOME'] || File.join(ENV['HOME'], '.local', 'share')
          token_file = File.join(data_home, 'alces', 'portal_id')

          unless File.exist?(token_file)
            STDERR.puts "Cannot access #{token_file}: No such file"
            exit 1
          end
          unless File.readable?(token_file)
            STDERR.puts "Cannot read #{token_file}: Permission denied"
            exit 1
          end

          File.read(token_file).split(':')[2].chomp
        end
      end
    end
  end
end

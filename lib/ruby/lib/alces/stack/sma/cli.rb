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
# https://github.com/alces-software/symphony                                       #
#                                                                              #
################################################################################
require 'alces/stack'
require 'alces/stack/sma/connector'
require 'alces/tools/cli'
require 'alces/tools/ssl_configurator'
require 'getoptlong'

module Alces
  module Stack
    module SMA
      class CLI

        include Alces::Tools::CLI

        root_only
        name 'alces-sma'
        description 'Connect to an Alces SMA daemon and execute commands'
        log_to File.join(Alces::Stack.config.log_root,'alces-sma.log')

        option :address,
               'Specify hostname or IP address of listening SMA daemon',
               '--address', '-a',
               default: '127.0.0.1',
               required: true

        option :port,
               'Specify port number of listening SMA daemon',
               '--port', '-p',
               default: '25200',
               required: true

        option :nossl,
               'Connect to SMA daemon without SSL',
               '--no-ssl',
               flag: true,
               default: false,
               required: true

        option :cert,
               'Path to SSL certificate file',
               '--cert',
               default: File.join(Alces::Stack.config.ssl_root,'daemon-client_crt.pem'),
               required: true
        
        option :key,
               'Path to SSL key file',
               '--key',
               default: File.join(Alces::Stack.config.ssl_root,'daemon-client_key.pem'),
               required: true
        
        option :cacert,
               'Path to SSL certificate authority file',
               '--cacert',
               default: File.join(Alces::Stack.config.ssl_root,'alces-ca_crt.pem'),
               required: true
        
        class << self
          def cli_usage
            "#{super} <command>"
          end
          
          def usage_text
            t = super 
            t << <<EOF


COMMANDS

   errors
     Display current error information

   dump <base|live|merged|find> [output filename] <find_key>
     Dump YAML machine information

   action <key> <action>
     Call action on a specified key

   actionsequence <name> [forward|reverse]
     Call action sequence <name> specify direction

   console
     Establish an interactive console session with SMA
EOF
          end
        end

        def execute
          if command = ARGV.shift
            ssl_config = Alces::Tools::SSLConfigurator::Configuration.new({
                                                                            certificate: cert,
                                                                            key: key,
                                                                            ca: cacert
                                                                          })
            connector = Connector.new(address, port, nossl, ssl_config)
            if connector.connected?
              exit 1 unless connector.execute(command, *ARGV)
            else
              STDERR.puts "EXITING!"
              exit 1
            end
          else
            usage
          end
        end
      end
    end
  end
end


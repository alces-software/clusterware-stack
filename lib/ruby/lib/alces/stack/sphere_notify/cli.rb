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
require 'alces/tools/cli'
require 'alces/tools/ssl_configurator'
require 'sphere_client'

module Alces
  module Stack
    module SphereNotify
      class CLI
        include Alces::Tools::CLI

        root_only
        name 'alces-sphere-notify'
        description 'Send a notification to an Alces Sphere daemon'
        log_to File.join(Alces::Stack.config.log_root,'alces-sphere-notify.log')

        option :address,
               'Specify hostname or IP address of listening Sphere daemon',
               '--address', '-a',
               default: '127.0.0.1',
               required: true

        option :port,
               'Specify port number of listening Sphere daemon',
               '--port', '-p',
               default: '25269',
               required: true

        option :nossl,
               'Connect to Sphere daemon without SSL',
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

   prod <service> [ARGS]
     Send a prod for the specified service.  Content provided on standard input; optional service arguments provided after service name.

EOF
          end
        end

        def ssl_opts
          {
            certificate: cert,
            key: key,
            ca: cacert
          }
        end

        class SSL < Struct.new(:ssl_opts)
          include Alces::Tools::SSLConfigurator
          def ssl
            Alces::Tools::SSLConfigurator::Configuration.new(ssl_opts)
          end
        end

        def conn_opts
          ssl = SSL.new(ssl_opts)
          conn_opts = {
            address: "#{address}:#{port}"
          }.tap do |h|
            h[:ssl_config] = ssl.ssl_config unless nossl
          end
        end

        def conn
          SphereClient::Connection.new(conn_opts)
        end

        def execute
          if ARGV.empty?
            usage
          else
            cmd = ARGV.shift.downcase
            case cmd
            when 'prod'
              doc = STDIN.read
              prodee = ARGV.shift
              args = {
                :args => ARGV,
                :input => doc
              }
              if conn.prod(prodee, args)
                STDERR.puts "#{$0}: OK - prod completed successfully"
              else
                raise "FAIL - unrecognized service, malformed prod message or other processing issue"
              end
            else
              usage
            end
          end
        end
      end
    end
  end
end

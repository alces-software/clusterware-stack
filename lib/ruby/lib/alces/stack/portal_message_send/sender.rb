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
require 'rest-client'
require 'yaml'

module Alces
  module Stack
    module PortalMessage
      class Sender
        PEPPER = 'VifWanOjvawedCyirsOfHutwiekotEraitt2friowwerk0slawbAbIOcoofOvsel'.freeze

        def initialize(config)
          @config = config
          raise "Missing authentication token" if @config[:auth_token].nil?
        end

        def send(message_name, message_data)
          h = {
            :accept => 'application/x-vnd.alces-software.webapp.api+json'
          }
          ::RestClient.post(uri, {message: {name: message_name, payload: message_data}}, h)
        rescue RestClient::Exception, SystemCallError
          STDERR.puts("Sending failed") {$!}
          STDERR.puts($!.message)
        end

        private

        def uri
          @uri ||=
            begin
              scheme = @config[:scheme] || 'http'
              host = @config[:host] || 'localhost'
              unless @config[:port] == :default
                port = ":#{@config[:port] || 8080}"
              end
              auth_token = @config[:auth_token]
              "#{scheme}://#{host}#{port}/messages?auth_token=#{auth_token}"
            end
        end
      end
    end
  end
end


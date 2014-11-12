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
# http://www.alces-software.org/symphony                                       #
#                                                                              #
################################################################################
require 'alces/stack'
require 'alces/stack/profile'
require 'alces/tools/cli'

module Alces
  module Stack
    module Booter
      class CLI
        include Alces::Tools::CLI

        root_only
        name 'alces-node-booter'
        description "Automatically detect booting node and set its build profile"
        log_to File.join(Alces::Stack.config.log_root,'alces-node-booter.log')

        option :hostnames,
               'Specify names of machines to boot identifier/hostname (comma separated)',
               '--identifier', '-n',
               required: true

        option :profile,
               'Specify profile name',
               '--profile', '-p',
               require: true

        def setup_signal_handler
          trap('INT') do
            (@booters || []).each { |booter| booter.cleanup unless booter.nil? }
            STDERR.puts "Exiting..." unless @exiting
            @exiting = true
            Kernel.exit(0)
          end
        end

        def execute
          setup_signal_handler
          @booters=[]
          hostnames.split(",").each do |host|
            booter=Alces::Stack::Booter::Booter.new(host,profile)
            @booters << booter
            booter.listen!
            STDERR.flush
          end
          sleep
        end
      end
    end
  end
end

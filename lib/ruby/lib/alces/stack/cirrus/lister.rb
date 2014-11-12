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
require 'alces/cirrus'
require 'alces/tools/logging'

module Alces
  module Stack
    module Cirrus
      module Lister
        include Alces::Tools::Logging

        class << self
          def hr(n)
            puts "#{"+#{'-'*22}"*n}+"
          end

          def row(*fields)
            format = "#{"| %20s "*fields.count}|\n"
            printf(format, *fields)
          end

          def execute
            fields = 4
            hr(fields)
            row('Identifier', 
                'Group', 
                'Hostname', 
                'Primary MAC Address')
            hr(fields)
            Alces::Cirrus::Machine.all.each do |machine|
              row(machine.identifier,
                  machine.machine_group.name,
                  machine.hostname,
                  machine.primary_nic.hwaddr)
            end
            hr(fields)
          end
        end
      end
    end
  end
end

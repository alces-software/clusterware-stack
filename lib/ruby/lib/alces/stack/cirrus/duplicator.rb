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
require 'alces/stack/cirrus/helpers'

module Alces
  module Stack
    module Cirrus
      module Duplicator
        extend Alces::Stack::Cirrus::Helpers

        class << self
          def duplicate(base_name, count = 1)
            integer_count = Integer(count) rescue nil
            if integer_count
              name = nil
              name_str = "incremented identifier"
              count = integer_count
              raise "Illegal count value: #{count} -- must be 1 < count < 50" if count < 1 || count > 50
            else
              name = count
              name_str = "explicit identifier '#{name}'"
              count = 1
            end
            machine = find_machine(base_name)
            say "Creating #{count} duplicate(s) of #{machine.identifier} (#{machine.hostname}) with #{name_str}..."
            count.times do
              machine = machine.copy!
              unless name.nil?
                machine.identifier = name
                machine.save!
              end
              say "Created #{machine.identifier}."
            end
            puts "Duplication completed."
          end
        end
      end
    end
  end
end

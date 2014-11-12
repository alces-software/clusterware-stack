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
      module Deleter
        extend Alces::Stack::Cirrus::Helpers

        class << self
          def delete(names,options = {})
            machines = names.map do |n|
              find_machine(n)
            end.uniq

            unless options[:force]
              msg = <<EOF
Going to delete the following nodes:
  #{machines.map{|m|"#{m.identifier} (#{m.hostname})"}.join("\n  ")}
EOF
              return unless confirm(msg)
            end

            info("Deleting machines"){machines}

            machines.each do |m|
              say "Deleting machine: #{m.identifier} (#{m.hostname})"
              m.destroy
            end
            puts "Deletion completed."
          end
        end
      end
    end
  end
end

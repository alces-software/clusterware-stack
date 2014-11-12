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
require 'alces/stack/helpers'

module Alces
  module Stack
    module Cirrus
      module Helpers
        include Alces::Stack::Helpers

        def find_machine(name)
          if name[0..0] == '+'
            hostname = name[1..-1]
            Alces::Cirrus::Machine.all.find do |x|
              x.full_hostname == hostname || x.hostname == hostname
            end.tap do |m|
              raise "Unable to locate machine by hostname: #{hostname}" if m.nil?
            end
          else
            Alces::Cirrus::Machine.find_by_identifier(name).tap do |m|
              raise "Unable to locate machine by identifier: #{name}" if m.nil?
            end
          end
        end
      end
    end
  end
end

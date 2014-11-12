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
      module NicManager
        extend Alces::Stack::Cirrus::Helpers
        
        class << self
          def setmac(name, hwaddr, intf = :primary)
            hwaddr = hwaddr.downcase
            raise "Hardware address is invalid: #{hwaddr}" unless valid_hwaddr?(hwaddr)
            machine = find_machine(name)
            nic = find_nic(machine, intf)
            say "Updating hardware address of #{nic.name} for #{machine.identifier} (#{machine.hostname}) to #{hwaddr}..."
            nic.hwaddr = hwaddr
            nic.save!
            puts 'Update completed.'
          end

          def find_nic(machine, intf)
            if intf == :primary
              machine.primary_nic
            else
              machine.nics.find {|nic| nic.name == intf }
            end.tap do |nic|
              raise "Unable to locate NIC named: #{intf}" if nic.nil?
            end
          end

          def valid_hwaddr?(hwaddr)
            hwaddr =~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/i
          end
        end
      end
    end
  end
end

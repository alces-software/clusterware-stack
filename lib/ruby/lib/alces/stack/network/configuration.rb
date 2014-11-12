################################################################################
# (c) Copyright 2007-2011 Alces Software Ltd & Stephen F Norledge.             #
#                                                                              #
# ALCES SOFTWARE HPC CLUSTER MANAGEMENT SUITE                                  #
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
require 'alces/tools/core_ext/object/blank'
require 'alces/tools/file_management'

module Alces
  module Stack
    module Network
      class Configuration < Struct.new(:root, :member, :interface_names, :forcemacs, :forcedhcp, :forcenoboot)
        include Alces::Tools::FileManagement

        def initialize(*args)
          super
          self.interface_names = interface_names.split(',')
          self.forcedhcp = forcedhcp.nil? ? [] : forcedhcp.split(',')
          self.forcenoboot = forcenoboot.nil? ? [] : forcenoboot.split(',')
          self.member=member
        end

        def interfaces
          @interfaces ||= find_interfaces
        end

        def noboot?(intf_name)
          forcenoboot.include?(intf_name)
        end

        def dhcp?(intf_name)
          forcedhcp.include?(intf_name)
        end

        def read_mac?
          forcemacs
        end

        def getmac(intf_name)
          (read("/sys/class/net/#{intf_name}/address").chomp rescue nil).tap do |r|
            # XXX - better logging
            raise "Could not determine MAC address for #{intf_name}" if r.nil?
          end
        end

        def read_name?
          forcename
        end

        def getname(intf)
          if intf.is_slave?
            intf.slave_name
          elsif intf.id.to_s.to_i != 0
            if intf.bmc?
              'bmc'
            elsif intf.ib?
              find_ib_by_id(intf.id.to_s.to_i)
            elsif intf.eth?
              find_eth_by_id(intf.id.to_s.to_i)
            else
              return intf.id
            end
          else
            intf.name
          end
        end

        private

        def find_eth_by_id(id)
          (Dir::entries('/sys/class/net/').select {|x| x=~/^eth\d|^em\d|^p\d*p/}.sort {|x,y|
            if (x =~ /^eth|^em/) && (y =~ /^eth|^em/)
              if (x =~ /^eth/) && (y =~ /^em/)
                -1
              elsif (y=~ /^eth/) && (x=~/^em/)
                1
              else
                x <=> y
              end
            else
              x <=> y
            end
          }|| [])[id-1]  
        end

        def find_ib_by_id(id)
          (Dir::entries('/sys/class/net/').select {|x| x=~/^ib/}.sort || [])[id-1]
        end

        def find_interfaces
          if interface_names.first.downcase == 'all'
            member.config.interfaces
          else
            interface_names.each_with_object([]) do |name, intfs|
              intfs << member.config.interfaces.find {|intf| intf.name == name}
            end.compact
          end
        end

      end
    end
  end
end  

################################################################################
# (c) Copyright 2007-2012 Stephen F Norledge.                                  #
#                                                                              #
# Symphony - Operating System Content Deployment Framework                     #
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
require 'yaml'
require 'alces/stack/profile/profile'

module Alces
  module Stack
    module Profile
      class Interface < ConfigData

        SUPPORTED_TYPES=[:ETH,:BMC,:IB,:BONDMASTER,:BONDSLAVE,:ETHVLAN,:ETHALIAS]
        SLAVE_TYPES=[:BOND,:ALIAS,:VLAN,:NONE]

        def initialize(hsh,dataset=nil)
          super
          @name=hsh[:name] || hsh[:id]
          @type=hsh[:type]
          @mac=hsh[:mac]
          @rolls=hsh[:rolls]
          @enabled=hsh[:enabled]
          @static=hsh[:static]
          @parent=hsh[:parent]
          @addr=hsh[:addr]
          @mask=hsh[:mask]
          @network=hsh[:network]
          @gateway=hsh[:gateway]
          @dns=hsh[:dns]
          @domain=hsh[:domain]
          validate!
        end

        def name
          getData(@name)
        end

        def id
          name
        end

        def mac
          getData(@mac)
        end

        def enabled?
          @enabled.nil? ? true : @enabled #default to enable the interface if its not specified
        end

        def type
          @type.to_s.empty? ? :ETH : @type.to_s.upcase.to_sym
        end

        def is_static?
          @static.nil? ? has_all_static_info? : @static
        end

        def dynamic?
          !is_static?
        end

        def eth?
          [:ETH,:BONDMASTER,:BONDSLAVE,:ETHVLAN,:ETHALIAS].include? type
        end

        def bmc?
          [:BMC].include? type
        end

        def ib?
          [:IB].include? type
        end

        def has_all_static_info?
          !addr.empty? && !network.empty? && !mask.empty?
        end

        def parent
          getData(@parent)
        end

        def is_slave?
          [:ETHVLAN,:ETHALIAS,:BONDSLAVE].include? type
        end

        def slave_name
          case slave_type
          when :ALIAS
            "#{parent}:#{name}"
          when :VLAN
            "#{name}.#{parent}"
          else
            name
          end
        end

        def slave_type
          case type
          when :ETHVLAN
            :VLAN
          when :ETHALIAS
            :ALIAS
          when :BONDSLAVE
            :BOND
          else
            :NONE
          end
        end

        def slave_name
          case type
          when :ETHVLAN
            parent + "." + name
          when :ETHALIAS
            parent + ":" + name
          when :BONDSLAVE
            name
          else
            name
          end
        end

        def addr
          getData(@addr)
        end

        def mask
          getData(@mask)
        end

        def network
          getData(@network)
        end

        def gateway
          getData(@gateway)
        end

        def domain
          getData(@domain)
        end

        def dns  
          (@dns || []).collect {|d| eval_string(d)}
        end

        def roles
          (@roles || []).collect {|r| eval_string(r)}
        end

        def to_s
          "".tap {|str|
            str << "Name: #{name}\n"
            str << "Type: #{type}\n"
            str << "Mac: #{mac}\n" unless mac.empty?
            unless roles.empty?
              str << "Roles:\n"
              roles.each do |role|
                str << "- #{role}\n"
              end
            end
            str << "Mode: #{is_static? ? 'STATIC' : 'DYNAMIC'}\n"
            str << "Enabled: #{enabled? ? 'YES' : 'NO' }\n"
            str << "Domain: #{domain}\n" unless domain.empty?
            if is_slave?
              str << "SlaveType: #{slave_type}\n"
              str << "SlaveName: #{slave_name}\n"
            end       
            if is_static?
              str << "IPv4 Address: #{addr}\n"
              str << "IPv4 Netmask: #{mask}\n"
              str << "IPv4 Network: #{network}\n"
              str << "Gateway: #{gateway}\n" unless gateway.empty?
              unless dns.empty?
                str << "DNS Servers\n"
                dns.each do |server|
                  str << "- #{server}\n"
                end
              end
            end
          }
        end

        def validate!
          raise ValidationError, "Name or ID must not be empty" if name.empty? && id.empty?
          raise ValidationError, "Type in invalid" unless SUPPORTED_TYPES.include? type
          if is_static?
            raise ValidationError, "Addr is invalid" if addr.empty?
            raise ValidationError, "Mask is invalid" if mask.empty?
            raise ValidationError, "Network is invalid" if network.empty?
          end 
        end
      end
    end
  end
end

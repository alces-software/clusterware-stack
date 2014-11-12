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
# https://github.com/alces-software/symphony                                       #
#                                                                              #
################################################################################
require 'erb'

module Alces
  module Stack
    module Network
      class InterfaceTemplate
        class << self
          def render(intf, config, os_type)
            new(intf, config, os_type).render
          end
        end

        def initialize(intf, config, os_type)
          @intf = intf
          @config = config
          @os_type = os_type
        end

        def render
          case @os_type
            when :SUSE
              render_suse
            else
              render_rh
          end
        end

        def render_rh
          ERB.new(<<TEMPLATE, nil, '%').result(binding)
#Configured by alces-network, manual changes may be lost
DEVICE=<%= name %>
% unless hwaddr.to_s.empty? || (@intf.type == :BONDMASTER)
HWADDR=<%= hwaddr %>
% end
NM_CONTROLLED=no
USERCTL=no
DEVICETYPE=<%= type %>
ONBOOT=<%= onboot %>
% if @intf.eth?
TYPE=Ethernet
% end
% if @intf.is_slave?
% case @intf.slave_type
% when :VLAN
VLAN=yes
% when :BOND
SLAVE=yes
MASTER=<%= @intf.parent%>
BOOTPROTO=none
% end
% end
% unless @intf.slave_type == :BOND
% if dhcp?
BOOTPROTO=dhcp
% else
BOOTPROTO=none
NETMASK=<%= @intf.mask %>
IPADDR=<%= @intf.addr %>
% unless @intf.network.to_s.empty?
NETWORK=<%= @intf.network %>
%   end
% unless @intf.gateway.to_s.empty?
GATEWAY=<%= @intf.gateway %>
%   end
% unless (@intf.dns.empty? rescue false)
%  @intf.dns.each_index do |i|
DNS<%=i+1%>=<%=@intf.dns[i]%>
%  end
% end
% end
% end
TEMPLATE
        end

        def render_suse
          ERB.new(<<TEMPLATE, nil, '%').result(binding)
#Configured by alces-network, manual changes may be lost
% if dhcp?
BOOTPROTO='dhcp'
% else
BOOTPROTO='static'
IPADDR='<%= @intf.addr %>'
NETMASK='<%= @intf.mask %>'
% unless @intf.network.to_s.empty?
NETWORK='<%= @intf.network %>'
% end
% end
STARTMODE='<%= onboot %>'
BROADCAST=''
ETHTOOL_OPTIONS=''
MTU=''
NAME=''
REMOTE_IPADDR=''
USERCONTROL='no'
INTERFACETYPE='<%= type %>'
TEMPLATE
        end

        def method_missing(s, *a, &b)
          if @intf.respond_to?(s)
            @intf.send(s, *a, &b)
          elsif @config.respond_to?(s)
            @config.send(s, *a, &b)
          else
            super
          end
        end

        def type
          if @intf.eth?
            'eth'
          elsif @intf.ib?
            'ib'
          elsif @intf.bmc?
            'bmc'
          else
            'eth'
          end
        end

        def onboot
          if eth? || ib?
            case @os_type
            when :SUSE
              (noboot?(name) || !@intf.enabled?) ? 'manual' : 'auto'
            else
              (noboot?(name) || !@intf.enabled?) ? 'no' : 'yes'
            end
          else
            case @os_type
              when :SUSE
                'off'
              else
                'no'
              end
          end
        end

        def name
          getname(@intf)
        end

        def dhcp?
          @config.dhcp?(name) || @intf.dynamic?
        end

        def hwaddr
          if read_mac?
            getmac(name) rescue @intf.mac
          else
            @intf.mac
          end
        end
      end
    end
  end
end

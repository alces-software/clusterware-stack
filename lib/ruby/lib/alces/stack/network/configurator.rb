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
require 'alces/tools/file_management'
require 'alces/tools/core_ext/object/blank'
require 'alces/stack/network/interface_template'
require 'alces/tools/logging'
require 'alces/tools/system'

module Alces
  module Stack
    module Network
      class Configurator
        include Alces::Tools::FileManagement
        include Alces::Tools::System
        include Alces::Tools::Logging

        NETWORK_SCRIPT_PATH_REDHAT = 'etc/sysconfig/network-scripts'
        NETWORK_SCRIPT_PATH_SUSE = 'etc/sysconfig/network'
        NETWORK_SCRIPT_PREFIX = 'ifcfg-'

        class << self
          def configure(config)
            new(config).configure
          end
        end

        attr_accessor :config
        def initialize(config)
          self.config = config
        end

        def method_missing(s, *a, &b)
          config.respond_to?(s) ? config.send(s, *a, &b) : super
        end

        def configure
          msg="Configuring interfaces (#{interfaces.map{|i| i.name.empty? ? i.id : i.name}.join(',')}) for #{member.identifier} in #{network_script_path}."
          info msg
          puts msg
          mkdir_p(network_script_path)
          interfaces.each do |intf|
            write_config(intf)
          end 
          puts 'OK'
        end

        def write_config(intf)
          data = InterfaceTemplate.render(intf, config, os_type)
          fn = network_script_filename(intf)
          write(fn, data)
          puts "  Wrote: #{fn}"
        end

        private

        def os_type
          @os_type ||= is_suse? ? :SUSE : :REDHAT
	end

        def network_script_path
          @network_script_path ||= ::File::join(root,is_suse? ? NETWORK_SCRIPT_PATH_SUSE : NETWORK_SCRIPT_PATH_REDHAT)
        end

        def network_script_filename(interface)
          ::File::join(network_script_path,"#{NETWORK_SCRIPT_PREFIX}#{config.getname(interface)}")
        end
      end
    end
  end
end

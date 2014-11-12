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
require 'alces/tools/logging'
require 'alces/tools/execution'
require 'alces/stack/profile'
require 'ip'

module Alces
  module Stack
    module Booter
      PXEBASE='/var/lib/alces/nodeware/tftpboot/pxelinux.cfg'
      class Booter
        include Alces::Tools::Logging
        include Alces::Tools::Execution
        
        def initialize(name,profile)
          @name=name
          @profile=profile.to_s.upcase
          raise "#{@name}: Invalid profile: #{@profile}" if @profile.to_s.empty?
          raise "#{@name}: Unable to find profile" unless ::File::exists? ::File::join(PXEBASE,@profile)
          (Alces::Stack::Profile::ProfileManager.all_members.select{|m| m if (m.identifier == @name) || (m.config.machine.hostname == @name.to_s)} || []).first.tap do |machine|
            raise "Unable to find machine: #{@name}" if machine.nil?
            @hostname = machine.config.machine.hostname
            @ipaddr = machine.config.primary_interface.addr
          end
        end

        def listen!
          Thread.new do
            begin
              if poll
                raise "#{@name}: Node is currently booted, nodes must be powered off before they can be configured for rebuild"
              end
              
              raise "#{@name} Unable to write pxe configuration file" unless write_pxe!

              STDERR.puts "#{@name}: WAITING FOR #{@hostname} (#{@ipaddr}) TO APPEAR ON THE NETWORK, PLEASE BOOT IT NOW!"; STDERR.flush

              while !poll do
                sleep 1
              end

              STDERR.puts "#{@name}: Node detected, delaying clean.."; STDERR.flush
              sleep 30

              clean_pxe!
            rescue Exception => e
              warn "Node booter failed for #{@node}"
              STDERR.puts e; STDERR.flush
              raise
            end
          end
        end

        def cleanup
          clean_pxe!
        end

        private

        def poll
          run_bash("/bin/ping -W 2 -c 1 #{@ipaddr}").success?
        end

        def write_pxe!
          STDERR.puts "#{@name}: Writing PXE file.."; STDERR.flush
          run_bash("cp -pavf #{::File::join(PXEBASE,@profile)} #{::File::join(PXEBASE,hex)}")
        end

        def clean_pxe!
          STDERR.puts "#{@name}: Cleaning PXE file.."; STDERR.flush
          run_bash("rm -fv #{::File::join(PXEBASE,hex)}")
        end

        def hex
          IP.new(@ipaddr).to_hex.to_s.upcase
        end
      end
    end
  end
end

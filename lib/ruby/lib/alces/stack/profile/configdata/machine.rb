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
      class Machine < ConfigData

        VALID_DEVICES=['/dev/ttyS0','/dev/ttyS1','/dev/ttyS2']
        VALID_BAUDS=['110','200','1200','2400','4800','9600','19200','38400','57600','115200']

        def initialize(hsh,dataset=nil)
          super
          @hostname=hsh[:hostname]
          @cores=hsh[:cores]
          @serialconsole_device=hsh[:serialconsole_device] 
          @serialconsole_baud=hsh[:serialconsole_baud]
          @rsakey=hsh[:rsakey]
          @rsapubkey=hsh[:rsapubkey]
          validate!
        end

        def hostname
          getData(@hostname)
        end
   
        alias name :hostname

        def cores
          getData(@cores)
        end

        def rsakey
          getData(@rsakey)
        end

        def rsapubkey
          getData(@rsapubkey)
        end

        def serialconsole_device
          getData(@serialconsole_device)
        end

        def serialconsole_baud
          getData(@serialconsole_baud)
        end

        def has_serial_console?
          !(serialconsole_device.empty?) && !(serialconsole_baud.empty?)
        end
  
        def to_s
          "".tap {|str|
            str << "Hostname: #{hostname}\n"
            str << "Cores: #{cores}\n"
            str << "Serial Console Device: #{serialconsole_device}\n" unless serialconsole_device.empty?
            str << "Serial Console Baud: #{serialconsole_baud}\n" unless serialconsole_device.empty?
          }
        end

        def validate!
          raise ValidationError, "Hostname is empty" if hostname.empty?
          unless dataset.nil?
            raise ValidationError, "RSA key is invalid" if rsakey.empty?
          end
#          raise ValidationError, "RSA pub key is invalid" if rsapubkey.empty?
          raise ValidationError, "Core count is invalid" unless cores.to_i > 0
          (raise ValidationError, "Serial console device is invalid" unless VALID_DEVICES.include? serialconsole_device) unless serialconsole_device.empty?
          (raise ValidationError, "Serial console baud is invalid" unless VALID_BAUDS.include? serialconsole_baud) unless serialconsole_baud.empty?
        end
      end
    end
  end
end

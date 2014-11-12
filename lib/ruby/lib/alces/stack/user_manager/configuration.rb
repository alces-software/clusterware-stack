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
# http://www.alces-software.org/symphony                                       #
#                                                                              #
################################################################################
module Alces
  module Stack
    module UserManager
      class Configuration < Struct.new(:username, :home, :shell, :comment, :config, :parameters)
        def initialize(*)
          super
          parse_parameters!
        end

        def ldap_domain
          config['ldap_domain']
        end
        
        def ldap_manager
          config['ldap_manager']
        end

        def respond_to_missing?(s, include_private)
          parameters && parameters.key?(s)
        end

        def method_missing(s,*a,&b)
          if parameters && parameters.key?(s)
            parameters[s]
          else
            super
          end
        end

        private
        def parse_parameters!
          self.parameters = {}.tap do |h|
            unless parameters.nil?
              parameters.split(',').each do |p|
                k, v = p.split('=')
                h[k.to_sym] = v
              end
            end
          end
        end
      end
    end
  end
end  

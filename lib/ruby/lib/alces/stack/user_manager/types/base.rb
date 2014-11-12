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
require 'alces/tools/execution'
require 'alces/stack/user_manager/user_command_failure'

module Alces
  module Stack
    module UserManager
      module Types
        class Base
          include Alces::Tools::Execution

          def initialize(params)
            @params = params
          end
          
          def method_missing(s,*a,&b)
            if @params.respond_to?(s)
              @params.send(s, *a, &b)
            else
              super
            end
          end
          
          def create
            raise "UNSUPPORTED!"
          end
          def delete
            raise "UNSUPPORTED!"
          end
          def passwd
            raise "UNSUPPORTED!"
          end
          
          def fail(message, r)
            raise(UserCommandFailure.new(message, r))
          end
        end
      end
    end
  end
end

    

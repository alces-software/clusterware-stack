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
require 'alces/tools/execution'
require 'alces/tools/file_management'

module Alces
  module Stack
    module Repo
      class Mirror

        include Alces::Tools::Execution
        include Alces::Tools::FileManagement

        SUPPORTED_SCHEMES=['http']

        def mirror(url,target)
          mkdir_p target          
          raise 'Non path' unless ::File::directory? target.to_s 
          uri=URI(url + '/')
          scheme=uri.scheme
          raise "Unsupported Scheme '#{scheme}'" unless SUPPORTED_SCHEMES.include? scheme
          path=uri.path
          base=File::split(path).last
          depth=path.split('/').collect {|x| x unless x.to_s.empty?}.compact.length
          cmd="cd #{target} && wget --mirror --no-parent --no-host-directories --cut-dirs=#{depth} #{uri.to_s} 2>&1 && find #{target} -iname 'index.html*' -exec rm -v {} \\;"
          run_bash(cmd)
        end
      end
    end
  end
end


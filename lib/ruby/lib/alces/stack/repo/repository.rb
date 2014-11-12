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
require 'alces/stack/repo/yum_configurator'

module Alces
  module Stack
    module Repo
      class Repository
        class << self
          def filesafe(s)
            s.downcase.gsub(/[\W]![\.]/,'_')
          end
        end

        class InvalidRepoDefinition < StandardError; end

        attr_reader :name
        attr_writer :nicename
        attr_reader :baseurl
        attr_reader :priority
        attr_reader :extra_files
        attr_reader :link_dirs
        attr_accessor :gpgkey
        
        def initialize(name,baseurl)
          self.name=name
          @baseurl=baseurl=baseurl
          @is_local = false
          @extra_files=[]
          @link_dirs=[]
          @gpgkey=nil
        end
        
        def priority=(priority_in)
          priority=priority_in.to_i
          raise InvalidRepoDefinition, "Invalid priority: '#{priority_in}'" unless (priority >= 1 && priority <=99) 
          @priority=priority
        end
        
        def gpgcheck?
          @gpgkey.to_s.empty? ? false : true
        end
        
        def enabled?
          @enabled ||= false
        end
        
        def enable!
          @enabled=true
        end
        
        def disable!
          @enabled=false
        end
        
        def enabled
          enabled? ? 1 : 0
        end
        
        def gpgcheck
          gpgcheck? ? 1 : 0
        end
        
        def nicename
          @nicename || name
        end
        
        def name=(newname)
          @name = Repository.filesafe(newname)
        end
        
        def localize(localpath,localurl)
          YUMConfigurator::new.import_repo(self,localpath)
          @original_url=baseurl
          @baseurl="#{localurl}/#{name}/"
          @is_local=true
        end
        
        def updatecheck(localpath,localurl)
          YUMConfigurator::new.import_repo(self,localpath,true)
        end
        
        def restore
          @baseurl=@original_url unless @original_url.nil?
          @is_local=false
        end
        
        def is_local?
          @is_local
        end
        
        def to_s
          str=""
          str << "[#{name}]\n"
          str << "name=#{nicename}\n"
          str << "baseurl=#{baseurl}\n"
          str << "priority=#{priority}\n"
          str << "enabled=#{enabled}\n"
          str << "gpgcheck=#{gpgcheck}\n"
          str << "gpgkey=#{gpgkey}\n" if gpgcheck?
          str
        end
      end
    end
  end
end

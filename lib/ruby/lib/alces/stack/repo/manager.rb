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
require 'yaml'
require 'alces/tools/execution'
require 'alces/tools/file_management'
require 'alces/tools/config'
require 'alces/stack/repo/repository'
require 'alces/stack/repo/yum_configurator'

module Alces
  module Stack
    module Repo
      class Manager
        include Alces::Tools::Execution
        include Alces::Tools::FileManagement
        
        attr_accessor :local_repo_path, :local_repo_url, :yum_config_path
        
        def initialize
          @configfile=Alces::Tools::Config::find('repo.yml')    
          load_data
        end
        
        def add_repo(name,url,priority,nicename,gpgkey=nil)
          raise "Repo exists!" unless repo(name).nil?
          r=Repository.new(name,url)
          r.nicename=nicename unless nicename.to_s.empty?
          r.priority=priority unless priority.to_s.empty?
          r.gpgkey=gpgkey unless gpgkey.to_s.empty?
          repos << r
          save_data!
        end
        
        def import_repo(name)
          raise "Repo does not exist" if repo(name).nil?
          raise "Repo is already imported" if repo(name).is_local?
          repo(name).localize(local_repo_path,local_repo_url)
          save_data!
        end
        
        def update_repo(name)
          raise "Repo does not exist" if repo(name).nil?
          raise "Repo is not imported" unless repo(name).is_local?
          repo(name).localize(local_repo_path,local_repo_url)
        end
        
        def updatecheck_repo(name)
          raise "Repo does not exist" if repo(name).nil?
          raise "Repo is not imported" unless repo(name).is_local?
          return repo(name).updatecheck(local_repo_path,local_repo_url)
        end
        
        def export_repo(name)
          raise "Repo does not exist" if repo(name).nil?
          raise "Repo is not imported" unless repo(name).is_local?
          repo(name).restore
          save_data!
        end
        
        def remove_repo(name)
          raise "Repo does not exist" if repo(name).nil?
          repos.delete_if {|r| r.name == Repository::filesafe(name)}
          save_data!
        end
        
        def enable_repo(name)
          raise "Repo does not exist" if repo(name).nil?
          repo(name).enable!
          save_data!
        end
        
        def disable_repo(name)
          raise "Repo does not exist" if repo(name).nil?
          repo(name).disable!
          save_data!
        end

        def init(basefile)
          load_data(basefile)
          YUMConfigurator.new(yum_config_path).reset
          save_data!
        end

        def localize
          #localize the config
          @configfile=Alces::Tools::Config::local('repo.yml')
          #disable all the repo's
          repos.each do |r|
            r.disable!
          end
          #reset the yum repo's
          YUMConfigurator.new(yum_config_path).reset
          #save the new config (to the local file)
          save_data!
        end
        
        def reponames
          repos.collect {|r| r.to_s}
        end
        
        def save_data!
          begin
            data={'repos'=>repos}
            mkdir_p ::File::dirname(@configfile)
            raise unless write(@configfile,data.to_yaml)
          rescue Exception => e
            raise
            raise "Cannot save repo definitions to #{@configfile} [#{e.message}]"
          end
        end
        
        def repo(name)
          repos.select {|r| r.name == Repository::filesafe(name)}.first
        end
        
        def format_as_yum_conf(enabled_only=false)
          str=""
          repos.each do |repo|
            if enabled_only
              if repo.enabled?
                str << repo.to_s
                str << "\n"
              end
            else
              str << repo.to_s
              str << "\n"
            end
          end
          str
        end
        
        def to_s
          format_as_yum_conf
        end
        
        private
        
        def repos
          @repos ||= []
        end
        
        def load_data(duplicate_config=nil)
          begin
	    config=duplicate_config || @configfile
            f=YAML::load_file(config) 
            @repos=f['repos']
          rescue 
            raise "Cannot load repo definitions from #{@configfile}"
          end
        end
        
      end
    end
  end
end

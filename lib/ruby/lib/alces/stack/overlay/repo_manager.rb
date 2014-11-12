################################################################################
# (c) Copyright 2007-2010 Stephen F Norledge.                                  #
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
require 'alces/stack/overlay/repo'

module Alces
  module Stack
    module Overlay
      class RepoManager
        class << self
          def config=(config)
            raise "duplicate config" unless @config.nil?
            @config = config
            raise 'Invalid config' unless config['repo_paths'].kind_of? Array
            config['repo_paths'].each do |path|
              add_repo(path)	
            end
          end

          def config
            @config ||= default_config
          end
          
          def repo(name)
            repos[name.to_s.downcase]	
          end

          def add_repo(path)
            repo=Alces::Stack::Overlay::Repo.new(path,{:enable_local_apply=>config['enable_repo_execute']})
            raise 'Duplicate Repo' if repos.has_key?(repo.name.to_s.downcase)
            repos[repo.name.to_s.downcase]=repo
          end

          def has_repo?(name)
            repos.has_key?(name.to_s.downcase)
          end

          def repo_names
            repos.keys
          end

          private

          def repos
            @repos||={}
          end

          def default_config
            {
              'repo_paths'=>[],
              'enable_repo_execute'=>true
            }
          end
        end
      end
    end
  end
end

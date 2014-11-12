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
require 'alces/stack/profile/profile'

module Alces
  module Stack
    module Profile
      class ProfileManager
        class << self
          def config=(config)
            raise "duplicate config" unless @config.nil?
            @config = config
            raise 'Invalid config' unless config['profiles'].kind_of? Array
            config['profiles'].each do |path|
              load_profile(path)
            end
          end

          def config
            self.config=default_config if @config.nil?
            @config
          end
          
          def load_profile(path)
            profile=Alces::Stack::Profile::Profile::load(path)
            raise 'Duplicate Profile' if profiles.has_key?(profile.name.to_s.downcase)
            profiles[profile.name.to_s.downcase]=profile
          end

          def has_profile?(name)
            profiles.has_key?(name.to_s.downcase)
          end

          def profile(name)
            profiles[name.to_s.downcase]
          end

          def profile_names
            profiles.keys
          end

          def show_profiles
            profiles.each {|p| p.show}
          end

          def all_members
            profiles.values.collect {|p| p.members}.flatten
          end
    
          def profile_type_members(type)
            profiles.values.collect {|p| p.members if p.type.to_s == type.to_s}.flatten.compact
          end

          private

          def profiles
            config
            @profiles||={}
          end

          def default_config
            YAML::load_file(Alces::Tools::Config.find('alces-profile.yml'))
          end
        end
      end
    end
  end
end

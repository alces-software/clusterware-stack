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
require 'yaml'
require 'alces/stack/overlay/control'

module Alces
  module Stack
    module Overlay
      class Repo

        class NotEnabledError < StandardError; end

        INVALID_OVERLAY_NAMES=['.','..',]

        attr_reader :base_path

        def initialize(base_path,options={})
          raise 'path is nil' if base_path.to_s.empty?
          @base_path=::File::expand_path(base_path)
          @options={:enable_local_apply=>false}.merge(options)
          load_constants
          load_overlays
        end

        def name
          ::File::basename(base_path)      
        end

        def has_overlay?(name)
          !overlay(name).nil?
        end

        def overlays
          @overlays
        end

        def overlay_names
          overlays.collect {|x| x.name}
        end

        def overlay(name)
          (overlays.select {|x| x.name == name.to_s.downcase} || []).first
        end

        private

        def load_overlays
          @overlays=[]
          overlay_paths=Dir::entries(@base_path).select { |x| valid_overlay(x) }
          overlay_paths.each do |path|
            begin
              @overlays << Alces::Stack::Overlay::Control.new(::File::join(@base_path,path),{:constants=>@constants,:enabled=>@options[:enable_local_apply]})
            rescue Alces::Stack::Overlay::Control::ValidationError
              nil #skip invalid overlays and continue loading
            end
          end
        end
        
        def load_constants
          begin
            @constants=YAML::load_file(::File::join(@base_path,'constants.yml'))
          rescue Errno::ENOENT
            @constants={}
          end
        end
        
        def valid_overlay(x)
          return false if INVALID_OVERLAY_NAMES.include?(x)
          return false if x =~ /^\./
          return false unless ::File::directory?(::File::join(@base_path,x))
          true
        end
      end
    end
  end
end

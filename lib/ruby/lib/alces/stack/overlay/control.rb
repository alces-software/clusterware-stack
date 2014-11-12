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
# http://www.alces-software.org/symphony                                       #
#                                                                              #
################################################################################
require 'alces/stack/overlay/skeleton'
require 'alces/stack/overlay/script_set'
require 'alces/stack/overlay/repo'
require 'yaml'

module Alces
  module Stack
    module Overlay
      class Control
        class ValidationError < StandardError; end;
        attr_reader :base_path

        def initialize(path,options={})
          raise 'Path is nil' if path.to_s.empty?
          @base_path = path
          @options={:enabled=>false,:constants=>{}}.merge(options)
          validate!
        end

        def name
          ::File::basename(base_path).to_s.downcase
        end

        def skeleton_path
          'skeleton'
        end

        def script_path
          'scripts'
        end

        def partials_path
          'partials'
        end

        def validate!
          raise ValidationError, 'no name' if name.to_s.empty?
          raise ValidationError, 'skeleton not valid' unless skeleton.valid?
        end

        def skeleton(partial = nil)
          @skeleton ||= Skeleton::new(base_path,skeleton_path,{:constants=>@options[:constants],:enabled=>@options[:enabled]})
          @skeleton.dup.reduce(partial_targets(partial))
        end

        def scriptset(partial = nil)
          @scriptset ||= ScriptSet::new(base_path,script_path,{:enabled=>@options[:enabled],:constants=>@options[:constants]})
          @scriptset.dup.reduce(partial_scripts(partial))
        end
        
        def partials
          @partials ||= Dir[File.join(base_path, partials_path, '*.yml')].each_with_object({}) do |f,h|
            partial = YAML.load_file(f)
            if !partial.is_a?(Hash)
              raise ValidationError, "Invalid partial format: #{f}"
            elsif !partial[:scripts] && !partial[:targets]
              raise ValidationError, "Invalid partial -- neither targets nor scripts found: #{f}"
            end
            h[File.basename(f,'.yml')] = partial
          end
        end

        def partial_targets(name)
          partials[name] && (partials[name][:targets] || [])
        end

        def partial_scripts(name)
          partials[name] && (partials[name][:scripts] || [])
        end

        def partial?(name)
          !partials[name].nil?
        end
      end
    end
  end
end

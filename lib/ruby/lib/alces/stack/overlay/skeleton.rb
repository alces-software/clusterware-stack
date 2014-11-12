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
require 'find'
require 'yaml'
require 'alces/tools/logging'
require 'alces/stack/overlay/skeleton/file_action'

module Alces
  module Stack
    module Overlay
      class Skeleton
        include Alces::Tools::Logging

        EXCLUDES=[/\.svn/]
        
        def initialize(overlay_path,skeleton_path,options={})
          @overlay_path,@skeleton_path=overlay_path,skeleton_path
          raise 'empty skeleton path' if skeleton_path.to_s.empty?
          raise 'empty overlay path' if overlay_path.to_s.empty?
warn options.inspect
          @options={:enabled=>false}.merge(options)
        end
        
        def base_path
          ::File::join(@overlay_path,@skeleton_path)
        end
        
        def valid?
          ::File::directory?(base_path)
        end 
        
        def files
          @files||=parse_raw_files.sort
        end
        
        def reduce(applicable_targets)
          unless applicable_targets.nil?
            files.select! do |f|
              applicable_targets.include?(f.target_path)
            end
          end
          self
        end

        private
        
        def parse_raw_files
          arr=[]
          Find::find(base_path) { |path| arr << path }
          files=[]
          arr.each do |path|
            unless excluded_path(path)
              case ::File::extname(path)
              when '.delete'
                files << FileAction::new(:DELETE,path,strip_base(path),@options[:enabled],@options[:constants])
              when '.append'
                files << FileAction::new(:APPEND,path,strip_base(path),@options[:enabled],@options[:constants])
              when '.prepend'
                files << FileAction::new(:PREPEND,path,strip_base(path),@options[:enabled],@options[:constants])
              when '.perms'
                files << FileAction::new(:PERMS,path,strip_base(path),@options[:enabled],@options[:constants])
              when '.replace'
                files << FileAction::new(:REPLACE,path,strip_base(path),@options[:enabled],@options[:constants])
              when '.link'
                files << FileAction::new(:LINK,path,strip_base(path),@options[:enabled],@options[:constants])
              when '.template'
                files << FileAction::new(:TEMPLATE,path,strip_base(path),@options[:enabled],@options[:constants])
              when '.copy'
                files << FileAction::new(:COPY,path,strip_base(path),@options[:enabled],@options[:constants])
              else
                files << FileAction::new(:CREATE,path,strip_base(path),@options[:enabled],@options[:constants])
              end
            end
          end
          files
        end

        def excluded_path(path)
          return true if path == base_path
          EXCLUDES.each do |exclude|
            return true if path =~ exclude
          end
          return false
        end
        
        def strip_base(path)
          path.sub(/^#{base_path}/,'')
        end
      end
    end
  end
end

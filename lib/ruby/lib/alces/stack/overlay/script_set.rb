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
require 'find'
require 'alces/stack/overlay/script_set/script'

module Alces
  module Stack
    module Overlay
      class ScriptSet
        def initialize(overlay_path,scriptset_path,options={})
          @overlay_path,@scriptset_path=overlay_path,scriptset_path
          raise 'empty scriptset path' if scriptset_path.to_s.empty?
          raise 'empty overlay path' if overlay_path.to_s.empty?
          @options={:enabled=>false}.merge(options)
        end
        
        def base_path
          ::File::join(@overlay_path,@scriptset_path)
        end
        
        def valid?
          ::File::directory?(base_path)
        end 
        
        def scripts
          @scripts ||= (parse_raw_files.sort rescue [])
        end

        def reduce(applicable_scripts)
          unless applicable_scripts.nil?
            scripts.select! do |f|
              applicable_scripts.include?(File.basename(f.path))
            end
          end
          self
        end

        def pre_scripts(include_once=true)
          if include_once
            scripts.select {|x| x.type == :PRE || x.type == :PREONCE }.sort
          else
            scripts.select {|x| x.type == :PRE}.sort
          end
        end
        
        def post_scripts(include_once=true)
          if include_once
            scripts.select {|x| x.type == :POST || x.type == :POSTONCE}.sort
          else
            scripts.select {|x| x.type == :POST}.sort
          end
        end

        private
        
        def parse_raw_files
          arr=[]
          Find::find(base_path) { |path| arr << path }
          scripts=[]
          arr.each do |path|
            unless path == base_path
              if valid_script?(path)
                fname=::File::basename(strip_base(path)).split('_')
                case fname[0].to_s.upcase
                when 'PRE'
                  type=:PRE
                  fname.shift
                when 'POST'
                  type=:POST
                  fname.shift
                when 'PREONCE'
                  type=:PREONCE
                  fname.shift
                when 'POSTONCE'
                  type=:POSTONCE
                  fname.shift
                else
                  type=:POST
                end
                scripts << Script::new(type,fname[0].to_i,path,@options[:enabled],@options[:constants])
              end
            end
          end
          scripts
        end
        
        def strip_base(path)
          path.sub(/^#{base_path}/,'')
        end
        
        VALID_SCRIPTS=[".sh",".rb",".pl"]
        
        def valid_script?(path)
          VALID_SCRIPTS.include?(::File::extname(path))
        end        
      end
    end
  end
end

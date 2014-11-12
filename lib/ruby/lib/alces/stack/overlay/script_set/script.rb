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
require 'alces/tools/logging'
require 'alces/tools/execution'
require 'yaml'
require 'tempfile'

module Alces
  module Stack
    module Overlay
      class ScriptSet
        class Script
          
          TYPES=[:PRE,:PREONCE,:POST,:POSTONCE]
          DATAFILE='/.alces/alces-overlay-scritps.yml'

          attr_reader :type
          attr_reader :sequence
          attr_reader :path
          
          include Alces::Tools::Logging
          include Alces::Tools::Execution
          include Alces::Tools::FileManagement
          
          def <=>(anOther)
            if type =~ /^PRE/ && anOther.type =~ /^POST/
              return 1
            elsif type =~ /^POST/ && anOther.type =~ /^PRE/
              return -1
            else
              if sequence == 0 #0 is actually very low priority
                return -1
              end
              if sequence > anOther.sequence
                return 1
              elsif sequence < anOther.sequence
                return -1
              else
                return 0
              end
            end 
          end
          
          def initialize(type,sequence,path,enabled,constants={})
            raise 'Invalid script type' unless TYPES.include? type
            @type=type
            @sequence=sequence.to_i
            raise 'Invalid path' unless (!path.to_s.empty? && ::File::exists?(path))
            @path=path
            @enabled=enabled
            @constants=constants || {}
          end 
          
          def to_s
            case type
            when :PRE
              "Pre execute #{path}"
            when :POST
              "Post execute #{path}"
            when :PREONCE
              "Pre execute [ONCE] #{path}"
            when :POSTONCE
              "Post execute [ONCE] #{path}"
            end
          end

          def enable!
            @enabled = true
          end
          
          def enabled?
            @enabled
          end
          
          def execute(options={})
            info "Executing Overlay script #{path}"
            options={:force=>false,:hostname=>nil}.merge(options)
            debug "Options -> #{options.inspect}"
            raise Alces::Stack::Overlay::Repo::NotEnabledError, 'Not Enabled' unless enabled?
            begin
              begin
                tempfile="/tmp/symphony-script.#{$$}.#{::File::extname(path)}"
                render_script(path,tempfile,options)
              rescue Exception=>e
                warn "Render failure [#{e.message}]"
                warn e
                return false
              end
              res=Bundler.with_clean_env do
                info "Executing script @ #{tempfile}"
                run_script(tempfile)[:exit_status].success? rescue false
              end
            rescue
              raise
            ensure 
              File::delete(tempfile) if ::File::exists? tempfile
            end
            record_execution if res
            res
          end

          def skip_run?
            type =~ /ONCE$/ && state.has_key?(path)
          end

          private
  
          def template_language(path)
            case path.split('.')[-2]
            when 'liquid'
              'liquid'
            when 'erb'
              'erb'
            end
          end 

          def render_script(src_file, dest_file, local_constants={})
            info("Evaluating template #{src_file}")
            src_string = read(src_file)

            debug("Template content"){src_string}

            output = case (lang = template_language(src_file))
                     when NilClass
                       TemplateRenderer.evaluate(src_string, @constants.merge(local_constants))
                     when 'liquid', 'erb'
                       ServiceRenderer.evaluate(src_string, lang, @constants.merge(local_constants))
                     else
                       raise "Unrecognised template language: #{lang}"
                     end
            if dest_file.nil?
              output
            else
              info "Installing template to #{dest_file}"
              write(dest_file, output)
            end
          end

          def state
            @state ||= YAML.load_file(DATAFILE) rescue {}
          end

          def record_execution
            state[path]=Time::now.strftime("%Y-%m-%d %H:%M:%S")
            mkdir_p ::File::dirname(DATAFILE)
            write(DATAFILE,state.to_yaml,{:mode=>0600})
          end

        end
      end
    end
  end
end

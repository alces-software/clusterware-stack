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
require 'alces/tools/execution'
require 'alces/tools/file_management'
require 'alces/tools/logging'
require 'erb'
require 'alces/renderer_client'
require 'alces/stack/profile'

module Alces
  module Stack
    module Overlay
      class Skeleton
        class FileAction
          include Alces::Tools::Logging
          include Alces::Tools::Execution
          include Alces::Tools::FileManagement

          class ValidationError < StandardError; end
          
          VALID_ACTIONS=[:DELETE,:CREATE,:REPLACE,:TEMPLATE,:PREPEND,:APPEND,:COPY,:LINK,:PERMS]
          TAILS=['.append','.prepend','.perms','.delete','.replace','.copy','.link','.template','.liquid','.erb']

          attr_reader :action,:src_path
          
          def <=>(anOther)
            if VALID_ACTIONS.index(action) > VALID_ACTIONS.index(anOther.action)
              return 1
            elsif VALID_ACTIONS.index(action) < VALID_ACTIONS.index(anOther.action)
              return -1
            else
              if src_path.split('/').size > anOther.src_path.split('/').size
                return 1
              elsif src_path.split('/').size < anOther.src_path.split('/').size
                return -1
              else
                return 0
              end	
            end
          end
          
          def initialize(action,src_path,tar_path,enabled=false,constants={})
            raise 'Invalid action' unless VALID_ACTIONS.include? action
            raise 'Invalid src path' unless ::File::exists? src_path
            raise "Invalid target path '#{tar_path}'" if tar_path.to_s.empty?
            @action,@src_path,@tar_path=action,src_path,tar_path
            @enabled=enabled
            @constants=constants || {}
          end
          
          def target_path
            @target_path||=(remove_action(@tar_path))
          end
          
          def template_language
            case @src_path.split('.')[-2]
            when 'liquid'
              'liquid'
            when 'erb'
              'erb'
            end
          end

          def src_path
            @src_path
          end
          
          def to_s
            case action
            when :CREATE
              "Creating #{target_path} using #{src_path} as a template"
            when :REPLACE
              "Replacing #{target_path} with #{src_path}"
            when :DELETE
              "Deleting #{target_path}"
            when :PREPEND
              "Prepending #{target_path} with contents of #{src_path}"
            when :APPEND
              "Appending #{target_path} with contents of #{src_path}"
            when :PERMS
              "Setting ownership and permission on #{target_path} with values from #{src_path}"
            when :LINK
              "Linking file at #{target_path} to target values from #{src_path}"
	    when :COPY
              "Copying file to #{target_path} from source values from #{src_path}"
            when :TEMPLATE
              "Installing template at #{src_path} to #{target_path}"
            else
              raise "Unknown"
            end
          end
          
          def enable!
            @enabled = true
          end

          def enabled?
            @enabled
          end
          
          def execute(options={})
            info "Applying Overlay skeleton file #{src_path}"
            options={:force=>false,:hostname=>nil}.merge(options)
            debug "Options -> #{options.inspect}"
            raise Alces::Stack::Overlay::Repo::NotEnabledError, 'Not enabled' unless enabled?
            do_action(options)
          end
          
          def src_as_yaml
            @yaml||=YAML::load_file(@src_path)
          end
          
          private
          
          def do_action(options)
            case action
            when :CREATE
              do_create(options)
            when :REPLACE
              do_replace(options)
            when :DELETE
              do_delete(options)
            when :PREPEND
              do_prepend(options)
            when :APPEND
              do_append(options)
            when :LINK
              do_link(options)
            when :COPY
              do_copy(options)
            when :TEMPLATE
              do_template_replace(options)
            when :PERMS
              do_perms(options)
            end
          end
          
          def remove_action(path)
            TAILS.each {|tail| path.sub!(/#{tail}$/,'')}
            path
          end
          
          def do_create(options)
            if ::File::directory?(@src_path)
              debug "DETERMINE IF DIRECTORY EXISTS - #{target_path} - AND CREATE IT AT #{target_path}" 
              if ::File::directory? target_path
                debug "Directoy already exisited at #{target_path} - skipping"
                res="SKIP_EXISTS"
              else
                res=mkdir_p(target_path) rescue false
              end
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - AND COPY IT FROM #{src_path} TO #{target_path}"
              begin
                if ::File::exists? target_path
                  debug "File already exisited at #{target_path} - skipping"
                  res="SKIP_EXISTS"
                else
                  res = render_template(@src_path, target_path, options)
                end
              rescue Exception => e
                warn "Exception when performing create - #{e.message}"
                res=false
              end
              
            end
            res
          end
          
          def do_replace(options)
            if ::File::directory?(@src_path)
              debug "DETERMINE IF DIRECTORY EXISTS - #{target_path} - BACKUP DELETE AND RECREATE IT AT #{target_path}"
              
              res=backup(target_path)
              res && rm_r(target_path) rescue res=false
              res && mkdir_p(target_path) rescue res=false
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - OVERLAY TEMPLATE FROM #{src_path} TO #{target_path}"
              begin
                res = if_unchanged(target_path,options[:force]) do |f, exists|
                  if exists
                    raise "backup failed" unless backup(f)
                    rm(f)
                  end
                  if run_bash("file -b #{@src_path} | grep -i 'text'")[:exit_status].success?
                    render_template(@src_path, f, options)
                  else
                    run("cp -pavf #{@src_path} #{f}")[:exit_status].success?
                  end
                end || "SKIP_CHANGED"
              rescue Exception => e
                warn "Exception when performing replace - #{e.message}"
                res=false
              end
            end
            res
          end
          
          def do_template_replace(options)
            if ::File::directory?(@src_path)
              res=false #template not valid on directory - ignore
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - AND COPY IT FROM #{src_path} TO #{target_path}"
              begin
                res = if_unchanged(target_path,options[:force]) do |f, exists|
                  if exists
                    raise "backup failed" unless backup(f)
                    rm(f)
                  end
                  render_template(@src_path, f, options)
                end || "SKIP_CHANGED"
              rescue Exception
                warn("Exception when performing overlay template replace"){$!}
                res=false
              end
            end
            res
          end
          
          def do_delete(options)
            if ::File::directory?(@src_path)
              debug "DETERMINE IF DIRECTORY EXISTS - #{target_path} - BACKUP AND DELETE IT AT #{target_path}"
              res=backup(target_path)
              res &&= (rm_r(target_path) rescue false)
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - BACKUP AND DELETE IT AT #{target_path}"
              res=backup(target_path)
              res && res=(rm(target_path) rescue false)
            end
            res
          end
          
          def do_prepend(options)
            if ::File::directory?(@src_path)
              res=false #prepend not valid for directory - just ignore
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - BACKUP AND PREPEND IT WITH CONTENTS OF #{src_path} AT #{target_path}"
              str=read(src_path)
              #attempt a restore first and roll back the preppend if its been applied before
              restore(target_path) rescue nil
              begin
                if ::File::exists? target_path
                  raise 'backup failed' unless backup(target_path)
                  str=render_template(@src_path, nil, options)
                  res=prepend(target_path,str)
                else
                  res= render_template(@src_path,target_path, options)
                end
              rescue Exception => e
                warn "Exception when performing overlay template prepend - #{e.message}"
                res=false
              end
              res
            end
            res
          end
          
          def do_append(options)
            if ::File::directory?(@src_path)
              nil #append not valid for directory - just ignore
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - BACKUP AND APPEND IT WITH CONTENTS OF #{src_path} AT #{target_path}"
              str=read(src_path)
              #attempt a restore first and roll back the append if its been applied before
              restore(target_path) rescue nil
              begin
                if ::File::exists? target_path
                  raise 'backup failed' unless backup(target_path)
                  str=render_template(@src_path, nil, options)
                  res=append(target_path,str)
                else
                  res= render_template(@src_path, target_path, options)
                end
              rescue Exception => e
                warn "Exception when performing overlay template append - #{e.message}"
                res=false
              end
              res                
            end
            res
          end
          
          def do_perms(options)
            debug "DETERMINE IF FILE EXISTS - #{target_path} - SET OWNERSHIP AND PERMISSIONS TO CONTENTS OF #{target_path}"
            if ::File::exists? target_path
              unless src_as_yaml['owner'].nil?
                res=chown(src_as_yaml['owner'],src_as_yaml['group'],target_path) rescue false #deliberately non-recursive
              end
              res && res=chmod(perms_to_chmod(src_as_yaml['perms']),target_path) rescue false
            end
          end
          
          def do_link(options)
            if src_as_yaml['type'].to_s.downcase == 'directory'
              debug "DETERMINE IF DIRECTORY EXISTS - #{target_path} - AND LINK IT TO CONTENTS OF #{src_path}"
              if ::File::directory? target_path
                debug "Directory already exisited at #{target_path} - skipping"
                res="SKIPEXISTS"
              else
                link_target=src_as_yaml['target'].to_s
                res=ln_s(link_target, target_path) rescue false
              end
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - AND LINK IT TO CONTENTS OF #{src_path}"
              if ::File::exists? target_path
                debug "File already exisited at #{target_path} - skipping"
                res="SKIPEXISTS"
              else
                link_target=src_as_yaml['target'].to_s
                res=ln_s(link_target,target_path)
              end
            end
            res
          end

          def do_copy(options)
            res = nil
            if src_as_yaml['type'].to_s.downcase == 'directory'
              debug "DETERMINE IF DIRECTORY EXISTS - #{target_path} - AND RECURSIVELY COPY SOURCE DEFINED IN #{src_path}"
              if ::File.directory?(target_path)
                if src_as_yaml['force']
                  debug "Directory already exists at #{target_path} - removing due to force flag"
                  rm_r(target_path)
                else
                  debug "Directory already exists at #{target_path} - skipping"
                  res = "SKIPEXISTS"
                end
              end
              unless res
                copy_source = src_as_yaml['source'].to_s
                res = cp_r(copy_source, target_path, :preserve => true) rescue false
              end
            else
              debug "DETERMINE IF FILE EXISTS - #{target_path} - AND COPY SOURCE DEFINED IN #{src_path}"
              if ::File.exists?(target_path) && !src_as_yaml['force']
                debug "File already exisited at #{target_path} - skipping"
                res = "SKIPEXISTS"
              else
		rm_f(target_path) if src_as_yaml['force']
                copy_source = src_as_yaml['source'].to_s
                res = cp(copy_source, target_path, :preserve => true) rescue false
              end
            end
            res
          end

          private
          
          def render_template(src_file, dest_file=nil, local_constants={})
            info("Evaluating template #{src_file}")
            src_string = read(src_file)
            
            debug("Template content"){src_string}

            output = case (lang = template_language)
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

          def perms_to_chmod(in_perms)
            in_perms.to_s.rjust(4,'0').to_i(8)
          end
        end
      end
    end
  end
end

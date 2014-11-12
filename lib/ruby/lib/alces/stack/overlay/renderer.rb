################################################################################
# (c) Copyright 2007-2012 Alces Software Ltd & Stephen F Norledge.             #
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
require 'alces/tools/file_management'

module Alces
  module Stack
    module Overlay
      class ServiceRenderer
        class << self
          def evaluate(*args)
            new.evaluate(*args)
          end
        end

        def evaluate(src_string, lang, constants)
          begin
            renderer = Alces::RendererClient::Renderer.new(src_string, constants)
            renderer.render.content
          rescue Exception => e
            raise TemplateEvaluationError, e.message
          end
        end
      end
      class TemplateRenderer
        class TemplateEvaluationError < StandardError; end
        class << self
          def evaluate(*args)
            new.evaluate(*args)
          end
        end

        def evaluate(src_string, constants)
          @constants = constants
          [:profile,:hostname].each do |req|
            raise "Required Constant [#{req}] not defined" if @constants[req].nil?
          end
          @profile_manager=Alces::Stack::Profile::ProfileManager
          @profilemanager=@profile_manager
          @profile=@profile_manager.profile(@constants[:profile])
          @local=@profile.member_by_hostname(@constants[:hostname]) rescue @profile.magicmember
          @localconfig=@local.config
          @config=@localconfig
          ERB.new(src_string,0,'<>').result(binding)
          rescue Exception => e
            raise TemplateEvaluationError, e.message
        end
      end

      class Renderer
        extend Alces::Tools::FileManagement
        class << self
          def duplicate(path, src_dir, dest_dir)
            src_path = File.join(src_dir, path)
            dest_path = File.join(dest_dir, path)
            if File.exists?(dest_path)
              rm_r(dest_path)
            end
            if File.exists?(src_path)
              cp_r(src_path, dest_path)
            end
          end

          def patch_action(action, path)
            # monkey patch, woo!
            class << action
              attr_accessor :dest_path
              def target_path
                @target_path ||= File.join(dest_path,@tar_path)
              end
            end
            action.dest_path = path
          end

          def render(overlay, output_path, options)
            output_path = File.absolute_path(output_path)
            # copy all scripts and partials 
            base = overlay.base_path
            [overlay.script_path, overlay.partials_path].each do |p|
              print "Duplicating #{base}/#{p} to #{output_path}/#{p}: "
              if options[:dryrun]
                puts 'DRYRUN'
              else
                duplicate(p, base, output_path)
                puts 'OK'
              end
            end

            # copy everything in skeleton that's got an extension of .copy, .link, .perms and .delete
            skel_src_path = File.join(base, overlay.skeleton_path)
            skel_dest_path = File.join(output_path, overlay.skeleton_path)
            unless options[:dryrun]
              mkdir(skel_dest_path) unless File.exists?(skel_dest_path)
            end
            Dir.chdir(skel_src_path)
            Dir.glob("**/*{.copy,.link,.perms,.delete}", File::FNM_DOTMATCH).each do |src|
              dest_dir = File.join(skel_dest_path,File.dirname(src))
              print "Duplicating #{File.join(skel_src_path,src)} to #{File.join(skel_dest_path,src)}: "
              if options[:dryrun]
                puts 'DRYRUN'
              else
                if ::File::directory? src
                  rm_r(File.join(skel_dest_path,src)) rescue nil
		  mkdir_p(File.join(skel_dest_path,src))
                else
                  mkdir_p(dest_dir)
                  cp(src, dest_dir)
                end
                puts 'OK'
              end
            end

            # find everything else in skeleton and render the templates into the output directory
            overlay.skeleton.files.select do |x|
              [:CREATE,:REPLACE,:TEMPLATE,:PREPEND,:APPEND].include?(x.action)
            end.each do |x| 
              patch_action(x, skel_dest_path)
              print "#{x.to_s}: "
              STDOUT.flush;
              x.enable! if options[:forceenabled]
              if options[:dryrun]
                puts "DRYRUN"
              else
                res = x.execute(options[:constants])
                if res.kind_of? String
                  puts res
                else
                  res ? puts("OK") : puts("FAIL")
                end
              end
            end
          end
        end
      end
    end
  end
end

################################################################################
# (c) Copyright 2007-2011 Alces Software Ltd & Stephen F Norledge.             #
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
require 'alces/stack'
require 'alces/tools/cli'
require 'alces/tools/system'
require 'alces/stack/overlay/repo_manager'
require 'alces/stack/overlay/renderer'
require 'alces/stack/profile'

module Alces
  module Stack
    module Overlay
      class CLI
        include Alces::Tools::CLI
        extend Alces::Tools::System
        Alces::Tools::Logging.default = Alces::Tools::Logger.new('/dev/null')

        VALID_COMMANDS=['REPOLIST','OVERLAYLIST','PARTIALLIST','PROFILELIST','APPLY','RENDER']
        
        root_only
        
        log_to File.join(Alces::Stack.config.log_root,'alces-overlay.log')
        
        name 'alces-overlay'
        description 'Execute overlay procedures on local machine'
        
        option :command, {
          description: "Specify command #{VALID_COMMANDS}",
          short: "-c",
          long: "--command",
          required: true,
          included_in: VALID_COMMANDS
        }
        option :repo, {
          description: "Specify a repository name",
          short: "-r",
          long: "--repo",
          default: 'overlays',
          required: true,
          condition: lambda { |repo| Alces::Stack::Overlay::RepoManager.has_repo?(repo) }
        }

        def validate_repo?
          ['PARTIALLIST','OVERLAYLIST','APPLY','RENDER'].include?(command.upcase)
        end

        option :overlay, {
          description: "Specify an overlay name",
          short: "-o",
          long: "--overlay",
          required: true,
          validate_when: :validate_overlay?,
          method: :validate_overlay
        }

        option :partial, {
          description: "Specify a partial name",
          short: "-p",
          long: "--partial",
          validate_when: :validate_partial?,
          method: :validate_partial
        }

        def validate_overlay?
          ['PARTIALLIST','APPLY','RENDER'].include?(command.upcase) && profile.nil?
        end

        
        def validate_partial?
          ['PARTIALLIST','APPLY','RENDER'].include?(command.upcase)
        end

        def validate_overlay
          unless Alces::Stack::Overlay::RepoManager.repo(repo).has_overlay?(overlay)
            raise InvalidOption, 'Non-existent overlay specified'  
          end
        end

        def validate_partial
          return true if partial.nil?
          raise(InvalidOption, 'Partial not valid without overlay') if overlay.nil?
          unless RepoManager.repo(repo).overlay(overlay).partial?(partial)
            raise InvalidOption, 'Non-existent partial specified'
          end
        end

        option :target_hostname,
               description: "Specify a hostname",
               default: hostname.value,
               long: "--hostname"

        option :profile, {
          description: "Specify a profile name",
          long: "--profile",
          required: true,
          validate_when: :validate_profile?,
          condition: lambda { |profile| Alces::Stack::Profile::ProfileManager.has_profile?   (profile) }
        }

        flag :noscripts, {
          description: "Apply skeleton only and do not execute pre or post scripts",
          long: "--noscripts"
        }

        flag :noskel, {
          description: "Run scripts only and do not apply skeleton",
          long: "--noskel"
        }

        flag :nopostscripts, {
          description: "Do not run post scripts",
          long: "--nopostscripts"
        }

        flag :noprescripts, {
          description: "Do not run pre scripts",
          long: "--noprescripts"
        }

        flag :nooncescripts, {
          description: "Do not run PREONCE or POSTONCE scripts",
          long: "--nooncescripts"
        }

        flag :force, {
          description: "Replace files even if changed (DANGEROUS)",
          short: "-f",
          long: "--force"
        }

        flag :forcescripts, {
          description: "Run ONCE scripts even if they have previously been executed (DANGEROUS)",
          long: "--forcescripts"
        }
                
        flag :forceenabled, 
             description: 'Override global overlay disable flag (DANGEROUS)',
             long: '--force-enable'

        flag :dryrun, 
             description: 'Perform a dry run, showing what actions would be taken without making changes',
             long: '--dry-run'

        def validate_root?
          ['RENDER'].include?(command.upcase)
        end

        option :render_path, 
               description: 'Specify output directory for RENDER command',
               long: '--render-path',
               validate_when: :validate_root?,
               required: true,
               file_exists: true

        def validate_options
          Alces::Stack::Overlay::RepoManager.config = config
          super
        end
        
        def validate_profile?
          case command
            when /APPLY/i
              true
            when /RENDER/i
              true
            else
              false
          end
        end

        def execute
          case command
            when /REPOLIST/i
              repolist
            when /OVERLAYLIST/i
              overlaylist
            when /PARTIALLIST/i
              partiallist
            when /PROFILELIST/i
              profilelist
            when /APPLY/i
              apply
            when /RENDER/i
              render
          end
        end
        
        private
        
        def repolist
          puts
          puts "REPOLIST:"
          puts "---------"
          Alces::Stack::Overlay::RepoManager.repo_names.each do |name|
            puts "  #{name}"
          end
          puts
        end

        def overlaylist
          puts
          puts "OVERLAYLIST"
          puts "-----------"
          Alces::Stack::Overlay::RepoManager.repo(repo).overlay_names.each do |name|
            puts "  #{name}"
          end
          puts
        end

        def partiallist
          puts
          puts "PARTIALLIST"
          puts "-----------"
          Alces::Stack::Overlay::RepoManager.repo(repo).overlay(overlay).partials.keys.each do |name|
            puts "  #{name}"
          end
          puts
        end

        def profilelist
          puts
          puts "AVAILABLE PROFILES"
          puts "------------------"
          Alces::Stack::Profile::ProfileManager.profile_names.each do |profile|
            puts "  #{profile}"
          end
          puts
        end

        def render
          if !overlay.nil?
            render_overlay(repo,overlay)
          else
            Alces::Stack::Profile::ProfileManager::profile(profile).overlays.each do |repo,overlays|
              overlays.each do |overlay|
                render_overlay(repo,overlay)
              end
            end
          end
        end

        def render_overlay(repo,overlay)
          str = "RENDERING REPO:#{repo} OVERLAY:#{overlay} TO #{render_path}"
          puts str
          puts('-' * str.length)
          o = Alces::Stack::Overlay::RepoManager.repo(repo).overlay(overlay)
          Renderer.render(o, render_path, dryrun: dryrun, forceenabled: forceenabled, constants: {hostname: target_hostname, profile: profile})
        end

        def apply
          if !overlay.nil?
            apply_overlay(repo,overlay)
          else
            Alces::Stack::Profile::ProfileManager::profile(profile).overlays.each do |repo,overlays|
              overlays.each do |overlay|
                apply_overlay(repo,overlay)
              end
            end
          end
        end

        def apply_overlay(repo,overlay)
          puts
          str="APPLYING REPO:#{repo} OVERLAY:#{overlay} #{partial.nil? ? '' : "PARTIAL:#{partial} "}NOW:"
          puts str
          str.length.times { print '-'}; puts
          o = Alces::Stack::Overlay::RepoManager.repo(repo).overlay(overlay)
          begin
            unless noscripts || noprescripts
              o.scriptset(partial).pre_scripts(!nooncescripts).each do |x| 
                print "#{x.to_s}: "
                STDOUT.flush
                x.enable! if forceenabled
                if dryrun
                  puts "DRYRUN"
                elsif x.skip_run? && !forcescripts
                  puts "SKIPRUN"
                else
                  res = x.execute(hostname: target_hostname, force: force, profile: profile)
                  puts "#{res && "OK" || "FAIL"}"
                end
              end
            end
            unless noskel
              o.skeleton(partial).files.each {|x| 
                print "#{x.to_s}: "
                STDOUT.flush; 
                x.enable! if forceenabled
                if dryrun
                  puts "DRYRUN"
                else
                  res = x.execute(hostname: target_hostname, force: force, profile: profile)
                  if res.kind_of? String
                    puts res
                  else
                    res ? puts("OK") : puts("FAIL")
                  end
                end
              }
            end
            unless noscripts || nopostscripts
              o.scriptset(partial).post_scripts(!nooncescripts).each do |x| 
                print "#{x.to_s}: "
                STDOUT.flush
                x.enable! if forceenabled
                if dryrun
                  puts "DRYRUN"
                elsif x.skip_run? && !forcescripts
                  puts "SKIPRUN" 
                else
                  res = x.execute(hostname: target_hostname, force: force, profile: profile)
                  puts "#{res && "OK" || "FAIL"}"
                end
              end
            end
          rescue Alces::Stack::Overlay::Repo::NotEnabledError
            STDERR.puts "Overlay on this machine is disabled via the config file, please enable in order to apply overlays"
            exit 1
          end
          puts
        end
        
      end 
    end
  end
end


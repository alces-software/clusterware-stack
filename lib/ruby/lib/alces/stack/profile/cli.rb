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
# https://github.com/alces-software/symphony                                       #
#                                                                              #
################################################################################
require 'alces/stack'
require 'alces/tools/cli'
require 'alces/tools/system'
require 'alces/stack/profile'

module Alces
  module Stack
    module Profile
      class CLI
        include Alces::Tools::CLI
        extend Alces::Tools::System
        Alces::Tools::Logging.default = Alces::Tools::Logger.new('/dev/null')

        VALID_COMMANDS=['SHOW','LIST','MEMBER','ALLMEMBERS']
        
        root_only
        
        log_to File.join(Alces::Stack.config.log_root,'alces-profile.log')
        
        name 'alces-profile'
        description 'Execute profile commands'
        
        option :command, {
          description: "Specify command #{VALID_COMMANDS}",
          short: "-c",
          long: "--command",
          required: true,
          included_in: VALID_COMMANDS
        }

        option :profile, {
          description: "Specify a profile name",
          short: "-p",
          long: "--profile",
          required: true,
          validate_when: :validate_profile?,
          condition: lambda { |profile| Alces::Stack::Profile::ProfileManager.has_profile?   (profile) }
        }

        option :member, {
          description: "Specify a Member index",
          short: "-m",
          long: "--member",
          required: true,
          validate_when: :validate_member?
        }

        option :evalstring, {
          description: "Evaluate ruby code against a member config",
          short: "-e",
          long: "--eval",
          required: false,
        }

        option :index, {
          description: "Index value for magic member",
          short: "-i",
          long: "--index",
          required: false,
        }

        option :branch, {
          descripton: "Branch value for magic number",
          short: "-b",
          long: "--branch",
          required: false
        }

        def validate_options
          Alces::Stack::Profile::ProfileManager.config = config
          super
        end
        
        def validate_profile?
          case command
            when /^SHOW/i
              true
            when /^member/i
              true
            else
              false
          end
        end

        def validate_member?
          case command
            when /^member/i
              true
            else
              false
          end
        end

        def execute
          case command
            when /^list/i
              profilelist
            when /^show/i
              profileshow
            when /^member/i
              profileeval
            when /^allmembers/i
              allmembers
          end
        end
        
        private
        
        def profilelist
          puts
          puts "AVAILABLE PROFILES"
          puts "------------------"
          Alces::Stack::Profile::ProfileManager.profile_names.each do |profile|
            puts "  #{profile}"
          end
          puts
        end

        def profileshow
          puts Alces::Stack::Profile::ProfileManager.profile(profile)
        end

        def allmembers
          Alces::Stack::Profile::ProfileManager.all_members.each {|m| puts m; puts m.config}
        end

        def profileeval
          p=Alces::Stack::Profile::ProfileManager.profile(profile)
          if member=~/magic/i
            m=p.magicmember((index||1),[branch])
          else
            m=p.member(member)
          end
          if evalstring.nil?
            puts m.config
          else
            puts eval("m.config.#{evalstring}")
          end
        end

      end 
    end
  end
end


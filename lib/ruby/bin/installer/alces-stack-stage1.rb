#!/usr/bin/env ruby
###############################################################################
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
require 'fileutils'
require 'yaml'

module Alces
  module Stack
    module Interaction
      QUESTION_TYPES=[:YESNO]
      NOTICE_WIDTH=80

      class BadEntry < StandardError; end

      def question(type,message,options={})
        options={:description=>nil,:required=>false}.merge options
        puts
        case type
        when :YESNO
          return do_yesno(message,options)
        when :GETANYVALUE
          return do_getanyvalue(message,options)
        else
          raise "unknown question type"
        end
      end
      def say(message,options={})
        options={:indent=>0,:type=>:MESSAGE}.merge options
        result=true
        case options[:type]
        when :MESSAGE
          colour=options[:colour] ||  "\033[1m"
          puts colour + message.rjust(message.length + options[:indent]) + "\033[0m"
        when :HEADING
          puts format_notice(message,options[:colour]||"\033[33m")
        when :PROCESS
          message = "\033[36m" + message + "\033[0m" + " .. " 
          print message.rjust(message.length + options[:indent])
          begin
            yield ? (puts("\033[32mOK\033[0m"); result=true) : (puts("\033[31mFAIL\033[0m"); result=false)
          rescue Exception
            puts("\033[31mFAIL\033[0m")
            raise
          end
        else
          raise 'unknown message type'
        end
        result
      end
      private
      def do_yesno(message,options)
        ans=do_getanyvalue("#{message} [Y/N]: ",options)
        res=(ans.to_s.downcase =='y' || ans.to_s.downcase == 'yes') ? true : false
        do_exit_by_user if !res && options[:required]
        res
      end

      def do_getanyvalue(message,options)
        puts format_notice(options[:description]) unless options[:description].nil?
        print "\033[1m#{message}: \033[0m"
        ans=gets.chomp; puts
        ans.downcase
      end

      def format_notice(string,colour="\033[33m")
        char_count=0
        format_lines=[]
        format_string=''
        next_word=''
        string.each_line do |l|
          char_count=0
          l.chomp.each_char do |c|
            char_count+=1
            next_word << c
            if c == ' ' || char_count == string.length
              if char_count > (NOTICE_WIDTH - 4)
                format_lines << format_string; format_string=''
                char_count=next_word.length
              end
              format_string << next_word; next_word=''
            end
          end
          format_string << next_word unless next_word.to_s.empty?; next_word=''
          format_lines << format_string unless format_string.empty?; format_string=''
        end
        str=format_lines.collect {|l| "| #{l.center(NOTICE_WIDTH - 4)} |"}.push(''.ljust(NOTICE_WIDTH,'=')).insert(0,''.ljust(NOTICE_WIDTH,'=')).join("\n")
        colour + str + "\033[0m"
      end

      def do_exit_by_user
        say 'Exit on user request', {:type=>:HEADING,:colour=>"\033[31m"}
        exit 1
      end

      def do_exit_by_failure(message=nil,exception=nil)
        say "Exit due to failure#{" - #{message}" unless message.to_s.empty?}#{"\n[#{exception.message}]\n#{exception.backtrace}" unless exception.nil?}", {:type=>:HEADING,:colour=>"\033[31m"}
        exit 1
      end
    end

    class Installer
      DATAFILE='datafile.yml'
      ALCES_BASE='/opt/clusterware'
      LOG='/var/log/alces/alces-stack-installer.log'
      DOWNLOAD_URL="http://download.alces-software.com/db/"
      ALCES_REPO_TEMPLATES="#{ALCES_BASE}/etc/repotemplates"

      include Alces::Stack::Interaction
      def do_install
        say "Welcome to the Alces HPC Stack Installer for #{distro}\n Copyright(c) 2008-2012 Alces Software Ltd", {:type=>:HEADING} 
        question(:YESNO, 'Proceed with installation?', {:description=>'This program will setup this system to be an Alces HPC Stack master installer. Please note that it will make significant alterations to this system. It should only be executed on a clean machine which is intended for this purpose',:required=>true})
        ::FileUtils::mkdir_p ::File::dirname(LOG) rescue do_exit_by_failure 'Unable to create log dir'
        do_repo 
        do_symphony
        #do_overlay_setup
        do_alcesrepo
        do_package_install
        #do_overlay_package_install
        do_yum_update
        #do_database
        #do_network
        #do_overlay
        #do_reboot
        do_reboot
      end

      def distro
        @distro ||= determine_distro
      end

      private

      def do_symphony
        if ::File::exists? '/opt/clusterware/bin/alces'
          return false unless question :YESNO, 'Reinstall symphony?', {:description=>"Alces symphony is already installed on this system, it can be reinstalled if required"}
        else
          question :YESNO, 'Install Symphony?', {:description=>"The Alces HPC Stack required installation of the symphony tool suite",:required=>true}
        end
        begin
          packages=distro_select('Symphony dependency packages',data[:symphony_deps]).join(" ")
          distro_do 'Package Install', {
            :EL=>lambda {raise 'Yum install failed' unless say("Installing Symphony dependency packages", {:type=>:PROCESS,:indent=>2}) { wrap_exec "yum -e0 -y install #{packages}" }}
          }
          say("Installing Symphony..",{:type=>:MESSAGE,:indent=>2})
          raise "Symphony install failed" unless unwrapped_exec "curl http://download.alces-software.com/alces/bootstrap | /bin/bash "
          say("Installing Facilities..",{:type=>:MESSAGE,:indent=>2})
          raise "Symphony install failed" unless unwrapped_exec "/bin/bash -l -c '/opt/clusterware/bin/alces facility install packager'"
          raise "Symphony install failed" unless unwrapped_exec "/bin/bash -l -c '/opt/clusterware/bin/alces facility install stack'"
          say("Symphony install complete.",{:type=>:MESSAGE,:indent=>2})
        rescue StandardError=>e
          do_exit_by_failure "Unable to install symphony"
        end
      end
     
      def do_overlay_setup
        if ::File::exists? '/opt/clusterware/overlays/base'
          return false unless question :YESNO, 'Delete existing overlays?', {:description=>'Existing overlays have been detected on this system, they can be recreated if required'}
          say("Deleting existing overlays",{:type=>:PROCESS,:indent=>2}) { wrap_exec "rm -rvf /opt/clusterware/overlays/*" } || raise("Failed to delete eixiting overlays")
        else
          question :YESNO, 'Setup Overlays?', {:description=>"Overlays are not yet configured on this system, they can be created in /opt/clusterware/overlays automatically",:required=>true}
        end
        begin
          overlay_repo=distro_select('Overlay base path',data[:overlay_repo_path])
          say("Installing base overlay",{:type=>:PROCESS,:indent=>2}) { wrap_exec "cp -pav #{::File::join(overlay_repo,'base')}/* /opt/clusterware/overlays/."} || raise("base overlay install failed")
          features=[:MYSQL,:'ALCES-PORTAL',:'ALCES-PRIME',:'ALCES-GRIDSCHEDULER']
          conflicts={:'ALCES-PORTAL'=>[:'ALCES-PRIME'],:'ALCES-PRIME'=>[:'ALCES-PORTAL']}
          installed=[]
          begin
            feature=(question :GETANYVALUE, "Feature?", {:description=>"The Alces HPC Overlays support multiple feature, please choose from #{features.collect{|x| x.to_s}.inspect}, or press enter to continue",:indent=>2}).to_s.upcase.to_sym rescue ''
            unless feature.to_s.empty?
              raise BadEntry unless features.include? feature
              installed.each {|i|
                if (conflicts[feature] || []).include? i
                  say "Feature:#{feature} conflicts with Feature:#{i}", {:type=>:MESSAGE,:indent=>2}
                  raise BadEntry
                end
              }
              say("Installing Feature:#{feature} overlay",{:type=>:PROCESS,:indent=>2}) { wrap_exec "cp -pav #{::File::join(overlay_repo,feature.to_s.downcase)}/* /opt/clusterware/overlays/." } || raise("feature overlay install failed")
              installed << feature
              raise BadEntry 
            end
          rescue BadEntry
            retry
          end
          say("Setting permissions on overlay dir",{:type=>:PROCESS,:indent=>2}) { wrap_exec "chown -R root:root /opt/clusterware/overlays && chmod -R 600 /opt/clusterware/overlays"} || raise("Setting overlay permissions failed")
        rescue StandardError=>e
          do_exit_by_failure "Overlay setup failed - #{e.message}"
        end
      end

      def do_network
        return false unless question :YESNO, 'Configure Network Now?', {:description=>"The Alces HPC Stack can configure the networking on this machine based on a machine in the database.",:required=>false}
        begin
          profile=question :GETANYVALUE, "Machine profile", {:description=>"Enter this machines profile as defined in the database"}
          member=question :GETANYVALUE, "Machine member", {:description=>"Enter this machines member name as defined in the database"}
          say("Configuring Network",{:type=>:PROCESS,:indent=>2}) {
            wrap_exec "/bin/bash -l -c 'alces network -c configure --profile #{profile} --member #{member} --livemacs'" 
          } || raise('network configure failed')
        rescue StandardError=>e
          retry
        end
      end

      def do_alcesrepo
        return false unless question :YESNO, 'Switch to Alces repos?', {:description=>'If this is an internal system build it is recommended to switch all repos to the local Alces mirrors to speed up install and package download',:required=>:false}
        begin
          availablefiles=::Dir::entries(ALCES_REPO_TEMPLATES).select {|d| d =~ /yml$/}
          initfile=question :GETANYVALUE, "Repo init file?", {:description=>"Select a repo init file from those available:\n#{availablefiles.join("\n")}"}
          say("Init from chosen file",{:type=>:PROCESS,:indent=>2}) {
            wrap_exec "/bin/bash -l -c 'alces repo -c init -i #{::File::join(ALCES_REPO_TEMPLATES,initfile)}'"
          } || raise('init failed')
          distro_do 'Package manager clean command', {
          :SLES=>lambda {raise 'Zypper clean failed' unless say("Scrubbing ZYPPER cache", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'zypper clean' }},
          :EL=>lambda {raise 'Yum clean failed' unless say("Scrubbing YUM cache", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'yum clean all' }}
          } || raise('clean failed') 
        rescue StandardError=>e
          retry
        end
      end
 
      def do_database
       return false unless question :YESNO, 'Fetch Database?', {:description=>'The Alces HPC stack requires a infrastructure database, it is recommended that you fetch and install that database now.',:required=>false}
       begin
         db=question :GETANYVALUE, 'Database filename?', {:description=>'Enter the database filename on the Alces download server'}
         url="#{DOWNLOAD_URL}/#{db}"
         say("Fetching file:",{:type=>:PROCESS,:indent=>2}) {
           wrap_exec "curl -f #{url} -o /tmp/db-#{$$}.tgz"
         } || raise('download failed')
         say("Unpacking:",{:type=>:PROCESS,:indent=>2}) {
           wrap_exec "tar -zxvf /tmp/db-#{$$}.tgz -C #{ALCES_BASE}"
         } || raise('unpack failed')
       rescue StandardError=>e
         retry  
       ensure
         wrap_exec "rm -fv /tmp/db-#{$$}.tgz"
       end
      end

      def do_overlay
        begin
          say("Preparing alces overlay",{:type=>:PROCESS,:indent=>2}) { wrap_exec "sed -e \"s/%SERVER%/master/g\" -e \"s/%METHOD%/LOCAL/g\" -e \"s/%PROFILE%/headnode/g\" #{ALCES_BASE}/etc/init.d/alces-overlay > /etc/init.d/alces-overlay 2>/dev/null && chmod 700 /etc/init.d/alces-overlay" } || raise('failed to prepare alces-overlay')
          ans=question :YESNO, 'Start Overlay on next boot?', {:description=>'To properly configure this system an overlay must be run. This can happen automatically at boot',:required=>false}
          if ans
            say("Enabling alces overlay", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'chkconfig alces-overlay on' }
          else
            say("Disabling alces overlay", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'chkconfig alces-overlay off' }
          end
        rescue StandardError=>e
          do_exit_by_failure 'Unable to enable overlay', e
        end
      end

      def do_reboot
        return false unless question :YESNO, 'Reboot now?', {:description=>'To complete the Alces HPC Stack installation a reboot of the system is now recommended',:required=>false}
        begin
          say("Initiating reboot", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'shutdown -r now' }
        rescue StandardError=>e
          do_exit_by_failure 'Unable to reboot machine', e
        end
      end

      def do_repo
        question :YESNO, 'Would you like to proceed with YUM configuration', {:description=>'For some distributions the pacakge manager needs an initial configuration to allow dependency install. This next process can enable the repository for use against the Alces Download server',:required=>true}
        begin
          yumdata=distro_select('Package manager config data', data[:package_manager_config_data]) rescue nil
          unless yumdata.nil?
            say("Writing Package manager configuration", {:type=>:PROCESS,:indent=>2}) {
              yumconf=::File::open(distro_select('Package manager config filename',data[:package_manager_config_filename]),'w')
              yumconf.puts yumdata
              yumconf.close; true
            }
	    distro_do 'Package manager clean command', {
            :SLES=>lambda {raise 'Zypper clean failed' unless say("Scrubbing ZYPPER cache", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'zypper clean' }},
            :EL=>lambda {raise 'Yum clean failed' unless say("Scrubbing YUM cache", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'yum clean all' }}
            }
          else 
            say("Skipping package manager pre-setup - not necessary for this distribution",{:type=>:MESSAGE,:indent=>2})
          end
          #say("Installing RPM GPG Key", {:type=>:PROCESS,:indent=>2}) {
          #  ::FileUtils::mkdir_p(::File::dirname(data[:rpm_gpg_key_filename]))
          #  gpg_key=::File::open(data[:rpm_gpg_key_filename],'w')
          #  gpg_key.puts data[:rpm_gpg_key]
          #  gpg_key.close;
          #  ::File::chmod(0644,data[:rpm_gpg_key_filename])
          #  true
          #}
        rescue StandardError=>e
          do_exit_by_failure 'Unable to configure repos', e
        end
      end

      def do_package_install
        packages="alces-base alces-master-base alces-graphical-base alces-libs alces-hpc-libs alces-master-hpc-libs alces-base-management alces-master-management alces-master-hpc-management alces-master-base-tools alces-base-monitoring alces-master-monitoring alces-base-hpc-provisioning alces-master-hpc-provisioning alces-master-base-configs alces-master-hpc-configs alces-master-gridware alces-master-hpc-gridware"
        question :YESNO, 'Proceed with package install', {:description=>'Proceed with installation of packages from the Alces HPC Stack repositories.',:required=>true}
        begin
          distro_do 'Package Install', {
            :EL=>lambda {raise 'Yum install failed' unless say("Installing YUM packages", {:type=>:PROCESS,:indent=>2}) { wrap_exec "yum --config /opt/clusterware/etc/yum.conf -e0 -y groupinstall #{packages}" }}
          }
        rescue StandardError=>e
          do_exit_by_failure 'Unable to install required packages', e
        end 
      end

      def do_overlay_package_install
        question :YESNO, 'Proceed with overlay package install', {:description=>'Installed overlays have package dependencies, they can be installed now',:required=>true}
        begin
          distro_do 'Package Install', {
            :EL=>lambda {raise 'Yum install failed' unless say("Installing Overlay packages", {:type=>:PROCESS,:indent=>2}) { wrap_exec "yum --config /opt/clusterware/etc/yum.conf -e0 -y install `cat /opt/clusterware/overlays/deps/*.yml | while read l; do echo -n \"$l \"; done`"}}
          }
        rescue StandardError=>e
          do_exit_by_failure 'Unable to install overlay packages', e
        end
      end

      def do_yum_update
        question :YESNO, 'Proceed with system update', {:description=>'It is recommended to perform a full system update when installing the stack',:required=>true}
        begin
          distro_do 'Package manager update', {
          :SLES=>lambda {raise 'Zypper update' unless say("Running ZYPPER update", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'zypper -n update'}},
          :EL=>lambda {raise 'Yum update' unless say("Running YUM update", {:type=>:PROCESS,:indent=>2}) { wrap_exec 'yum --config /opt/clusterware/etc/yum.conf -e0 -y update'}}
          }
        rescue StandardError=>e
          do_exit_by_failure 'Unable to update system', e
        end
      end

      def determine_distro
        os_strings=data[:os_strings]
        begin
          s=File::read('/etc/issue')
          return os_strings[s] if os_strings.has_key? s
          raise
        rescue StandardError
          raise 'unable to determine distro - is this distribution supported?'
        end
      end

      def distro_matches
        data[:os_matches][distro] || []
      end

      def distro_select(info,hsh)
        ([distro] + distro_matches).each { |dist|
          return hsh[dist] if hsh.has_key? dist
        }
        raise "Unable to select distro value for #{info}"
      end

      def distro_do(info,hsh)
        ([distro] + distro_matches).each { |dist|
          return hsh[dist].call if hsh.has_key? dist
        }
        raise "Unable to select distro do for #{info}"
      end

      def data
        @data ||= YAML::load_file(DATAFILE) rescue do_exit_by_failure("Unable to open datafile",$!)
      end

      def wrap_exec(cmd)
        system "#{cmd} &>> #{LOG}" 
      end

      def unwrapped_exec(cmd)
        system "#{cmd}"
      end

    end
  end
end

if $0 == __FILE__

  i=Alces::Stack::Installer::new()
  i.do_install

end

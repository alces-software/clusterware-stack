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
# https://github.com/alces-software/symphony                                       #
#                                                                              #
################################################################################
require 'yaml'
require 'alces/stack/profile/profile_tools'
require 'alces/stack/profile/dataset'
require 'alces/stack/profile/config'
require 'alces/tools/execution'
require 'alces/tools/system'

module Alces
  module Stack
    module Profile
      module ProfileTools
        class ValidationError < StandardError; end;
      end
      class Profile
        include ProfileTools
        class << self
          def load(path)
            begin
              raw=YAML.load_file(path)
              self::new(raw)
            rescue
              raise #raise "Failed to load profile @ '#{path}'"
            end
          end

        end
        class Member
          include ProfileTools
          attr_reader :index,:identifier
          attr_reader :branch_keys
          def initialize(hsh)
            raise ValidationError, "Member is invalid" unless hsh.kind_of? Hash
            @index=hsh[:index]
            @branch_keys=(hsh[:branch_keys] || [] .compact rescue nil) || [hsh[:branch]]
            @identifier=hsh[:identifier] || hsh[:id]
          end
          alias id :identifier 
          def setconfig(config,dataset)
            @config=config
            @config.dataset=dataset
            @config.dataset.branch_keys=[identifier].concat branch_keys
            #OVERRIDE HARD KEYS
            @config.dataset.data[:INDEX]=index
          end
          def config
            validate!
            @config
          end
          def to_s
            "".tap {|str|
              str << "Index: #{index}\n"
              str << "  Identifier: #{identifier}\n"
              unless branch_keys.empty?
                str << "  Branches:\n"
                branch_keys.each do |branch|
                  str << "    - #{branch}\n"
                end
              end
            }
          end

          private
          def validate!
            raise ValidationError, "Member index (#{index}) is invalid" unless index.kind_of? Fixnum
            raise ValidationError, "Member identifier (#{identifier}) is invalid" if identifier.to_s.empty?
            raise ValidationError, "Branch keys are invalid" unless branch_keys.kind_of? Array
            begin
              @config.validate! unless @config.nil?
            rescue ValidationError => e
              raise ValidationError, "Failed to load profile member #{index}:#{identifier} (#{e.message})"
            end
          end

        end

        include Alces::Tools::Execution 
        include Alces::Tools::System
        attr_reader :name,:description,:config,:dataset
        
        def initialize(hsh)
          if !hsh.is_a?(Hash)
            raise ValidationError, "Invalid profile format"
          end
          @name=hsh[:name]
          @description=hsh[:description]
          @overlays=hsh[:overlays]
          @datasetfiles=hsh[:datasets].kind_of?(Array) ? hsh[:datasets] : (hsh[:datasets].nil? ? [hsh[:dataset]] : [hsh[:datasets]])
          @configfiles=hsh[:configs].kind_of?(Array) ? hsh[:configs] : (hsh[:configs].nil? ? [hsh[:config]] : [hsh[:configs]])
          @type=hsh[:type]
          @distro=hsh[:distro]
          @config=merge_configs(@configfiles)
          @dataset=merge_datasets(@datasetfiles)
          validate!
          (hsh[:members] || []).each do |member|
            if member.has_key?(:range)
              begin
                range=member[:range].split('..').inject { |s,e| s.to_i..e.to_i }
                raise unless range.kind_of? Range
                range.each do |index|
                  if member[:pad].nil?
                    identifier=(member[:identifier].to_s + index.to_s)
                  else
                    identifier=(member[:identifier].to_s + (index.to_s.rjust(member[:pad].to_i,'0')))
                  end
                  members << newMember(member.merge({:index=>index,:identifier=>identifier}))
                end
              rescue Exception => e
                raise "Failed to generate members from range (#{member[:range]}) [#{e.message}]"
              end 
            else
              members << newMember(member)
            end
          end
        end

	def members
          @members ||= []
        end

        def overlays
          @overlays ||= {}
        end
 
        def type
          @type || name
        end

        def distro
          @distro ||= 'UNKNOWN'
        end

        def to_s
          "".tap {|s|
            s << "name: #{@name}\n"
            s << "description: #{@description}\n"
            s << "distro: #{distro}\n"
            s << "members:\n"
            members.each do |member|
              s << ((member.to_s.split("\n").collect {|l| "  " + l}.join("\n")) + "\n")
            end
            s << "overlays:\n"
            overlays.each do |repo,overlay_names|
              s << "  Repo: #{repo}\n"
              overlay_names.each do |name|
                s << "  - #{name}\n"
              end
            end
            s << "config: #{config}\n"
            s << "dataset: #{dataset.inspect}\n"
          }
        end

        def member(id)
          members.select{|x| x.id.to_s == id.to_s}.first.tap {|x| x.nil? ? raise("Unable to find member with ID:(#{id})") : x}
        end

        def magicmember(id=1,branch_keys=[])
          newMember({:index=>id.to_i,:identifier=>'magic',:branch_keys=>branch_keys})
        end

        def localmember
          member_by_hostname(get_hostname)
        end

        def member_by_hostname(hostname)
          members.select{|x| x.config.machine.hostname == hostname rescue false}.first.tap {|x| x.nil? ? raise("Unable to find member with hostname:(#{hostname})") : x}
        end
        def distro_name
          distro.split("_").first rescue "UNKNOWN"
        end
        def distro_version
          distro.split("_").drop(1).join('_') rescue ""
        end
        private

        def validate!
          raise ValidationError, "Name cannot be empty" if name.to_s.empty?
          overlays.each do |repo,overlays|
            raise ValidationError, "Invalid overlay specfication in profile #{name}:#{repo}" unless overlays.is_a?(Array)
          end
          raise ValidationError, "Distro (#{distro}) is invalid" if distro.empty?
          #members
          unless members.empty?
            raise ValidationError, "Duplicate member index found" if members.collect{|x| x.index}.uniq.size != members.size
          end
        end
        def newMember(memberhash)
          m=Member::new(memberhash)
          m.setconfig(merge_configs(@configfiles),merge_datasets(@datasetfiles))
          m
        end
        def get_hostname
          @hostname||=value_or_fail('Could not determine local hostname') { hostname }
        end

        def merge_datasets(filenames)
          merged_ds=nil
          filenames.each do |dspath|
            ds=Dataset::load(dspath)
            if merged_ds.nil?
              merged_ds=ds
            else
              merged_ds.merge(ds)
            end
          end
          merged_ds
        end

        def merge_configs(filenames)
          merged_config=nil
          filenames.each do |configpath|
            config=Config::load(configpath)
            if merged_config.nil?
              merged_config=config
            else
              merged_config.merge(config)
            end
          end
          merged_config
        end
      end
    end
  end
end

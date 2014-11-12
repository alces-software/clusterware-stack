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
require 'alces/stack/profile/profile'

module Alces
  module Stack
    module Profile
      class ConfigData
        include Alces::Stack::Profile::ProfileTools
        include Alces::Stack::Profile::DatasetTools
        def initialize(hsh,dataset=nil?)
          if !hsh.is_a?(Hash)
            raise ValidationError, "Invalid config format"
          end
          self.dataset=dataset
        end
        def validate!
          raise ValidataionError, "Override me!"
        end
        protected 
        def getData(value)
          eval_string(value.nil? ? "" : value.to_s)
        end
      end
      class Config

        class << self
          def load(path)
            begin
              raw=YAML.load_file(path)
              self::new(raw[:config])
            rescue Exception => e
raise
              raise "Failed to load config at '#{path}' (#{e.message})"
            end
          end
        end

        include Alces::Stack::Profile::ProfileTools
        include Alces::Stack::Profile::DatasetTools
        
        def initialize(hsh=nil,datasets=nil)
          return self if hsh.nil?
          if !hsh.is_a?(Hash)
            raise ValidationError, "Invalid config format"
          end
          self.dataset=datasets
          @interfaces=[].tap {|interfaces|
            hsh[:interfaces].each {|attrs| 
              begin
                interfaces << Interface::new(attrs,dataset)
              rescue ValidationError=>e
                raise ValidationError, "Interface (#{attrs[:name] || 'unknown' rescue 'unknown'}) failed to load with messsage: '#{e.message}'"
              end
            }
          }
          @userdata=hsh[:user]
          begin
            @machine=Machine::new(hsh[:machine],dataset)
          rescue ValidationError=>e
            raise ValidationError, "Machine failed to load with message: '#{e.message}'"
          end
          begin
            @cluster=Cluster::new(hsh[:cluster],dataset)
          rescue ValidationError=>e
            raise ValidationError, "Cluster failed to load with message: '#{e.message}'"
          end
          validate!
        end

        def merge(another)
          @interfaces=another.interfaces unless another.interfaces.empty?
          @machine=another.machine unless another.machine.nil?
          @cluster=another.cluster unless another.cluster.nil?
          userdata.merge!(another.userdata)
          self
        end

        def interfaces
          @interfaces ||= []
        end

        def primary_interface
          pi=(interfaces.select {|i| i.domain == cluster.primarydomain})
          pi.empty? ? interfaces.first : pi.first
        end

        def machine
          @machine
        end

        def cluster
          @cluster
        end
  
        def user(key)
          eval_string(userdata[key.to_sym])
        end

        def dataset=(datasets)
          super
          interfaces.each {|i| i.dataset=self.dataset}
          machine.dataset=self.dataset unless machine.nil?
          cluster.dataset=self.dataset unless cluster.nil?
        end

	def to_s
          "".tap { |str|
            str << "Machine:\n"
            str << ((machine.to_s.split("\n").collect {|l| "  " + l}.join("\n")) + "\n")
            str << "Cluster:\n"
            str << ((cluster.to_s.split("\n").collect {|l| "  " + l}.join("\n")) + "\n")
            str << "Interfaces:\n"
            interfaces.each do |interface|
              str << "--\n"
              str << ((interface.to_s.split("\n").collect {|l| "  " + l}.join("\n")) + "\n")
              str << "--\n"
            end
            str << "User Data:\n" unless userdata.empty?
            userdata.each do |key,value|
              str << "  #{key}: #{user(key)}\n"
            end
          }
        end

        def interface_values(key)
          interfaces.collect {|i| i.send(key).empty? ? nil : i.send(key)}.compact
        end

        def validate!
          interfaces.each {|i| i.validate!}
          
          domains=interface_values(:domain)
          raise ValidationError, "Interfaces have duplicate domains" if (domains.uniq.size != domains.size)
          macs=interface_values(:mac)
          raise ValidationError, "Interfaces have duplicate macs" if (macs.uniq.size != macs.size) 
          interface_names={}
          interfaces.each { |i|
            if (interface_names[i.type] || []).include? i.name
              raise ValidationError, "Interfaces have duplicate names"
            else
              (interface_names[i.type] ||= []) << i.name
            end
          }
        end

        protected

        def userdata
          @userdata ||= {}
        end
      end
    end
  end
end

require 'alces/stack/profile/configdata/interface'
require 'alces/stack/profile/configdata/machine'
require 'alces/stack/profile/configdata/cluster'

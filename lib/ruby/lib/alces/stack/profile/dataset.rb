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
require 'erb'
require 'alces/stack/profile/profile_tools'
class Hash
  def deep_merge!(second)
    second.each_pair do |k,v|
      if self[k].is_a?(Hash) and second[k].is_a?(Hash)
        self[k].deep_merge!(second[k])
      elsif self[k].is_a?(Alces::Stack::Profile::Dataset) && second[k].is_a?(Alces::Stack::Profile::Dataset)
        self[k].merge(second[k])
      else
        self[k] = second[k]
      end
    end
  end
end

module Alces
  module Stack
    module Profile
      module DatasetTools
        def dataset=(datasets)
          dataset=(datasets.kind_of?(Array) ? merge_datasets(datasets) :  datasets)
          @dataset=dataset
        end
        def dataset
          @dataset
        end
        def eval_string(value)
          dataset.nil? ? value : (value.kind_of?(String) ? eval_erb(value) : value)
        end
        def dataset_value(key)
          value=dataset.value(key)
          value.kind_of?(String) ? eval_string(value) : value
        end
        alias dsv :dataset_value

        private

        def merge_datasets(array_of_datasets)
          array_of_datasets.each do |ds|
            dataset||=ds
            dataset.merge(ds) 
          end
          dataset
        end
 
        def eval_erb(string)
          calculate_in_sandbox(string)
        end

        class BlankSlate
          instance_methods.each do |name|
            class_eval do
              undef_method name unless name =~ /__|instance_eval|binding|object_id/
            end
          end
        end

        def calculate_in_sandbox(string)
          clean_room=BlankSlate.new
          erb=ERB::new(string)
          begin
            erb.result lambda {
              $SAFE = 4
              clean_room.instance_eval do
                binding
              end
            }.binding
          rescue Exception=>e
            raise "Error whilst evaluating dataset value => '#{string}' (#{e.message})"
          end
        end
      end
      class Dataset
        include ProfileTools
        class << self
          def load(path)
            begin
              raw=YAML.load_file(path)
              self::new(raw[:dataset])
            rescue
              raise
              raise "Failed to load dataset @ '#{path}'"
            end
          end
          def merge!(path,merge_data)
            begin
              raw=YAML.load_file(path) rescue {:dataset=>{}}
              raw[:dataset].deep_merge!(merge_data)
              ::File::write(path,raw.to_yaml); true
            rescue
              return false
            end
          end

        end

        def initialize(hsh={})
          if !hsh.is_a?(Hash)
            raise ValidationError, "Invalid dataset format"
          end
          hsh.each do |k,v|
            if v.kind_of? Hash
              datasets[k.to_sym]=Dataset::new(v)
            else
              data[k.to_sym] = v
            end
          end
          validate!
        end
       
        def data
          @data ||= {}
        end

        def datasets
          @datasets ||= {}
        end

        def merge(another)
          data.deep_merge!(another.data)
          datasets.deep_merge!(another.datasets)
          self
        end

        def value(tag)
          branch_value=runtime_data[tag.to_sym] || "" #RUNTIME DATA HAS HIGHEST PRIORITY
          #NOW TRY BRANCHES, LAST BRANCH MATCH WINS
          branch_keys.reverse_each do |branch_key|
            (branch_value=datasets[branch_key.to_sym].value(tag).to_s rescue "") if branch_value.to_s.empty?
          end
          #LASTLY TRY DEFAULT BRANCH
          branch_value.empty? ? data[tag.to_sym].to_s : branch_value
        end

        def branch_keys=(keys)
          @branchkeys=keys
        end
 
        def branch_keys
          @branchkeys ||= []
        end

        def runtime_data=(runtime_hash)
          raise ValidationError, "Runtime data invalid" unless runtime_hash.kind_of? Hash
          @runtime_data=runtime_data
        end

        def runtime_data
          @runtime_data ||= {}
        end

        #def to_s
        #  "".tap {|s|
        #    datasets.each do |k,ds|
        #      s << "Branch: #{k}\n"
        #      s << ((ds.to_s.split("\n").collect{|l| "  " + l}.join("\n")) + "\n")
        #    end
        #    data.each do |k,v|
        #      s << "#{k} => #{v.inspect}\n"
        #    end
        #  }
        #end

        private

        def validate!
          #raise ValidationError, "Name cannot be empty" if name.to_s.empty?
        end
      end
    end
  end
end

################################################################################
# (c) Copyright 2007-2011 Alces Software Ltd & Stephen F Norledge.             #
#                                                                              #
# Alces HPC Software Toolkit                                                   #
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
require 'sma-dao'
require 'readline'
require 'drb'
require 'alces/tools/ssl_configurator'
require 'timeout'

module Alces
  module Stack
    module SMA
      class Connector
        include Alces::Tools::SSLConfigurator

        attr_accessor :address, :ssl
        def initialize(address, port, insecure, ssl_config)
          self.address = "#{address}:#{port}"
          self.ssl = ssl_config unless insecure
          establish_connection(insecure)
        end
      
        def connected?
          true if @agent.ping rescue false
        end
      
        def establish_connection(insecure)
          STDERR.print "Establishing Connection... "
          STDERR.flush
          ssl_drb_config!
          @agent = DRbObject.new_with_uri("#{insecure ? 'druby' : 'drbssl'}://#{address}")
          begin
            Timeout.timeout(10) { @agent.ping }
            STDERR.puts "#{insecure ? 'Socket' : 'SSL'} connection established with agent on: #{address}"
          rescue TimeoutError
            raise TimeoutError, 'Timed out after 10 seconds'
          end
        rescue
          STDERR.puts "Unable to establish connection with agent on: #{address}"
          raise
        end
      
        def execute(command, *args)
          raise "Not Connected" unless connected?
          case command.to_s.downcase
          when "errors"
            mm=@agent.mismatches
            if mm.to_s.empty?
              puts "NO ERRORS"
              return true
            else
              puts mm
              return false
            end
          when "dump"
            dumpmode=args.shift
            dumpfile=args.shift.to_s
            case dumpmode.to_s.downcase
            when "live"
              dump=@agent.live_machine.to_yaml
            when "base"
              dump=@agent.base_machine.to_yaml
            when "merged"
              dump=@agent.merged_machine.to_yaml
            when "find"
              dumpkey = args.shift
              if dumpkey.nil?
                dumpkey = dumpfile || ""
                dumpfile = ""
              end
              if dumpkey.to_s.empty? 
                STDERR.puts "Please specify a key"
                return false
              end
              dump=@agent.find_by_key(dumpkey)
              if dump.nil?
                STDERR.puts "Unable to find key '#{dumpkey}'"
                return false
              else
                STDOUT.puts "Found '#{dumpkey}'"
                dump=dump.to_yaml
              end
            else
              STDERR.puts "Unrecognised dump mode #{dumpmode}"
              return false
            end
            if dumpfile.empty?
              puts dump
            else
              STDERR.puts "Dumping #{dumpmode} to #{dumpfile}"
              begin
                f=::File::open(dumpfile,'w')
                f.puts dump
                f.close
              rescue Exception => e
                STDERR.puts "Unable to dump to file"
                raise
              end
            end
            return true
          when "action"
            key=args.shift
            action=args.shift
            if key.to_s.empty? || action.to_s.empty?
              STDERR.puts "Please specify both key and action"
              return false
            end
            res=@agent.call_action(key,action)
            res.to_s.empty? ? puts("EMPTY") : puts(res)
            return true
          when "actionsequence"
            name=args.shift
            direction=args.shift.to_s
            direction="forward" if direction.empty?
            case direction
            when "forward"
              as=@agent.action_sequence_forward(name)
            when "reverse"
              as=@agent.action_sequence_reverse(name)
            else
              STDERR.puts "Unrecognised direction -> #{direction}"
              return false
            end
            if as.nil?
              STDERR.puts "Unable to find action sequence #{name}"
              return false
            end
            if as
              STDOUT.puts "Action sequence executed successfully"
              return true
            else
              STDERR.puts "Error whilst executing action sequence"
              return false
            end
          when 'console'
            console
          else
            STDERR.puts "Unrecognised command - #{command}"
            return false
          end
        end
        
        def console
          #activate command console
          while connected? && line = Readline.readline('sma> ', true)
            line.chomp
            case line
            when "exit"
              break
            when /^eval (.*)/
              puts "Sending call [#{line}]"
              cmd,args = $1.split(' ')
              begin
                puts "Output from call:"
                puts (eval("@agent.#{cmd}")).inspect
              rescue
                puts "ERROR -> #{$!.message}\n"
              end
            else
              puts "Sending call [#{line}]"
              cmd,args = line.split(' ')
              begin
                puts "Output from call:"
                puts @agent.send(cmd,*args).inspect
              rescue
                puts "ERROR -> #{$!.message}\n"
              end
            end
          end
        end
      end
    end
  end
end

################################################################################
# (c) Copyright 2007-2012 Alces Software Ltd & Stephen F Norledge.             #
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
# http://www.alces-software.org/symphony                                       #
#                                                                              #
################################################################################
require 'alces/tools/execution'
require 'alces/tools/file_management'
require 'alces/stack/repo/mirror'

module Alces
  module Stack
    module Repo
      class YUMConfigurator
        
        if ::File::directory? '/etc/zypp/repos.d'
          MODE=:zypp
          YUM_CONFIG_BASE="/var/lib/alces/nodeware/etc/zypp/"
        else
          MODE=:yum
          YUM_CONFIG_BASE="/var/lib/alces/nodeware/etc/yum.repos.d/"
        end
       
        def initialize(yum_config_path=nil)
          @yum_config_alces=::File::join((yum_config_path || YUM_CONFIG_BASE), 'Alces.repo')
        end
 
        include Alces::Tools::Execution
        include Alces::Tools::FileManagement
        
        #wipe all yum repo configuration
        def reset
          begin
            cmd="/usr/bin/find #{YUM_CONFIG_BASE} -iname *.repo -exec rm -v {} ;"
            raise if run(cmd).fail?
          rescue 
            raise "Failed to clear all yum repo configurations"
          end
        end
        
        def write_alces_repos(repomanager)
          begin
            data="# This file is maintained by alces-repo, changes are likely to be overwritten\n"
            data << repomanager.format_as_yum_conf(true)
            mkdir_p ::File::dirname(@yum_config_alces)
            raise unless write(@yum_config_alces,data,mode: 0644)
          rescue Exception => e
            raise "Failed to write repo config to '#{@yum_config_alces}' [#{e.message}]"
          end
        end
        
        def import_repo(inrepo,localpath,updatecheck=false)
          temp_repofile="/tmp/alces-repo.#{$$}"
          repo=inrepo.clone
          repo.restore
          repo.enable!
          begin
            data="# This file is maintained by alces-repo, changes are likely to be overwritten\n"
            data << repo.to_s
            raise unless write(temp_repofile,data,mode: 0644)
          rescue
            raise "Failed to write repo config to '#{filename}'"
          end
          begin
            repopath=::File::join(localpath,repo.name)      
            createrepo=false                    
            if repo.baseurl =~ /^file/ 
              clean_path=::File::join(repo.baseurl.gsub(/^file:\/\/\//,'/'))
              updatestr="--dry-run " if updatecheck
              res=run("/usr/bin/rsync --delete -pav #{updatestr}#{clean_path} #{repopath}")
              raise 'Failed to rsync' if res.fail?
              updates=res.stdout.to_s.split.select{|x| x =~ /.rpm$/}
              createrepo=true unless updatecheck
            else
              unless ::File::exists? '/usr/bin/reposync'
                res=Alces::Stack::Repo::Mirror.new.mirror(repo.baseurl,repopath)
                updates=res
              else
                updatestr="--urls " if updatecheck
                res=run("/usr/bin/reposync #{updatestr}--repoid=#{repo.name} --config=#{temp_repofile} -l -m --newest-only --download_path #{localpath}")
                raise 'Failed to run reposync' if res.fail?
                updates=res.stdout.to_s.split("\n").select{|x| x =~ /.rpm$/ && !(x =~ /Skipping existing/) }
                createrepo=true unless updatecheck
              end
            end
            
            if createrepo
              #remove link dirs before running createrepo or it will loop forever..
              (repo || []).link_dirs.each do |ld|
                rm_f(::File::join(repopath,ld))
              end
              
              comps=::File::join(repopath,'comps.xml')
              if ::File::exists? comps
                compsstr="-g comps.xml"
              end
              
              res=run("/usr/bin/createrepo #{compsstr} -q #{repopath}")
              raise "Failed to createrepo" if res.fail?
              
              str="################################\n(c) 2008-2011 Alces Software Ltd\n################################\nThis mirror is maintained by alces-repo and is a copy of the YUM repo at:\n#{repo.baseurl}\n\nLocal changes may be overwritten!"
              write(::File::join(repopath,'1-info.txt'),str,mode: 0644)
              
              #recreate link dirs (for anaconda)
              (repo.link_dirs || []).each do |ld|
                res=run("ln -sn . #{ld}",options: {:chdir=>repopath})
                raise "Failed to create link #{ld}" if res.fail?
              end
              
            end

            #download extra files
            (repo.extra_files || []).each do |hsh|
              dir=::File::join(repopath,::File::dirname(hsh[:dest]))
              dest=::File::join(repopath,hsh[:dest])
              mkdir_p dir
              res=run(['/usr/bin/wget','-q',hsh[:src],'-O',dest])
              raise "Failed to fetch #{hsh[:src]}" if res.fail?
            end


            updates
          rescue Exception => e
            raise "Failed to execute repo commands - #{e.message}"
          ensure
            begin
              raise unless rm_f temp_repofile
            rescue
              raise "Failed to delete temp repo file"
            end
          end
          return updates if updatecheck
          true
        end
        
      end
    end
  end
end

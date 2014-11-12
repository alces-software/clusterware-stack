#!/bin/bash
DIR=$(cd `dirname $0` && pwd)
cd $DIR/..
git archive master > stack.tar
if [ -x $(which gtar 2> /dev/null) ]; then
    TAR=gtar
else
    TAR=tar
fi
$TAR -rf stack.tar archives
gzip stack.tar
cp stack.tar.gz bootstrap/.
rm stack.tar.gz


#Installer
#(cd lib/ruby/bin/; git archive --format tar.gz master installer/) > alces-stack-stage1.tgz
#scp alces-stack-stage1.tgz root@download.alces-software.com:/var/www/html/alces
#rm alces-stack-stage1.tgz

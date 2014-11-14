################################################################################
##
## Alces HPC Software Stack - User helper directory creation on login
## Copyright (c) 2008-2013 Alces Software Ltd
##
################################################################################
export alces_PATH=/opt/clusterware
export alces_MODE=system

ARCHIVE_DIR=
SHAREDSCRATCH_DIR=
LOCALSCRATCH_DIR=/tmp/users

USERDIR=$USER/

export SKIP_USERS="root alces"
export LOWEST_UID=500

check_user() {
  for SKIPUSER in $SKIP_USERS; do
    if [ "$USER" ==  "$SKIPUSER" ]; then
      return 1
    fi
    if [ $LOWEST_UID -gt `id -u` ]; then
      return 1
    fi
  done
  return 0
}

do_userpath() {

  TYPE=$1
  LINK=$2
  BASEDIR=$3
  MODE=$4
  if [ -z $MODE]; then
    MODE=700
  fi
  if ! [ -z $BASEDIR ]; then
    TARGET_DIR=$BASEDIR/$USERDIR
    if ! [ -d $TARGET_DIR ] && [ -w $BASEDIR ]; then
      echo "Creating user dir for '$TYPE'"
      mkdir -m $MODE -p $TARGET_DIR
    fi
    TARGET_LINK=$HOME/$LINK
    if [ -d $TARGET_DIR ]; then
      if ! [ -f $TARGET_LINK ] && ! [ -L $TARGET_LINK ] && ! [ -d $TARGET_LINK ] ; then
        echo "Creating user link for '$TYPE'"
        if ! ( ln -sn $TARGET_DIR $TARGET_LINK 2>&1 ); then
          echo "Warning: A '$TYPE' directory is available but a link cannot be created on this node" >&2
      fi
      fi
    else
      if [ -L $TARGET_LINK ]; then
        echo "Warning: A '$TYPE' link exists but the target is not available on this node" >&2
      fi
    fi
  fi
}

if ( check_user ); then
  do_userpath "Local Scratch" localscratch $LOCALSCRATCH_DIR
  do_userpath "Shared Scratch" sharedscratch $SHAREDSCRATCH_DIR
  do_userpath "Archive" archive $ARCHIVE_DIR
fi

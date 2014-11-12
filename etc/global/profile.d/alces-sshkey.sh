################################################################################
##
## Alces HPC Software Stack - User ssh key creation on login
## Copyright (c) 2008-2013 Alces Software Ltd
##
################################################################################
export alces_PATH=/var/lib/alces/nodeware

export alces_MODE=system

export SKIP_USERS="root alces"
export LOWEST_UID=500

export KEYNAME=id_alcescluster
export SSHHOME=$HOME/.ssh/

export LOG=$HOME/alces-login.log

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

check_ssh_keys() {
  if ! [ -f $SSHHOME/$KEYNAME.pub ]; then
    return 1
  fi
  if ! [ -f $SSHHOME/$KEYNAME ]; then
    return 1
  fi
  return 0
}

new_key() {
  (
  echo "GENERATING SSH KEYPAIR - `date`"
  /usr/bin/ssh-keygen -q -t rsa -f $SSHHOME/$KEYNAME -C "Alces HPC Cluster Key" -N '' < /dev/null
  ) >> $LOG;
}
 
enable_key() {
  (
  echo "AUTHORIZING KEYS - `date`"
  cat $SSHHOME/$KEYNAME.pub >> $SSHHOME/authorized_keys
  chmod 600 $SSHHOME/authorized_keys
  ) >> $LOG;
}

if ( check_user ); then
  if !( check_ssh_keys ); then
   echo -n "Generating SSH keypair:"
   if ( new_key ); then
    echo 'OK'
    echo -n "Authorizing key:"
    enable_key && (echo 'OK') || (echo 'FAIL'; exit 1)
   else
    echo 'FAIL'
   fi
  fi
fi

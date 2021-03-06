#!/bin/bash

## Copyright (C) 2011, 2015  International Business Machines Corporation
## All Rights Reserved

################### parameters used in this script ##############################

#set -o xtrace
#set -o pipefail

here=$( cd ${0%/*} ; pwd )

administrator=streamsadmin
domain=CapabilitiesDomain
instance=CapabilitiesInstance

hostname=$( hostname )

################### functions used in this script #############################

die() { echo ; echo -e "\e[1;31m$*\e[0m" >&2 ; exit 1 ; }
step() { echo ; echo -e "\e[1;34m$*\e[0m" ; }

################################################################################

step "getting zookeeper connection string ..."
zkconnect=$( streamtool getzk --short )
[ -n "$zkconnect" ] || die "sorry, could not get zookeeper connection string"
export STREAMS_ZKCONNECT=$zkconnect

step "checking zookeeper at '$zkconnect' ..."
streamtool getzkstate || die "sorry, could not connect to zookeeper at '$zkconnect', $?"

$here/teardownCapabilities.sh

step "making Streams domain '$domain' ..."
streamtool mkdomain -d $domain || die "sorry, could not make Streams domain '$domain', $?"
streamtool genkey -d $domain || die "sorry, could not generate keys for Streams domain '$domain', $?"

step "setting dynamic service ports for Streams domain '$domain' ..."
streamtool setdomainproperty -d $domain jmx.port=0 jmx.startTimeout=60 || die "sorry, could not set JMX properties for Streams domain '$domain', $?"
streamtool setdomainproperty -d $domain sws.port=0 sws.startTimeout=60 || die "sorry, could not set SWS properties for Streams domain '$domain', $?"

# instead of 'streamtool registerdomainhost' and 'streamtool mkinstance --property instance.canSetPeOSCapabilities=true' below
# verify that 'root' user has executed:
# /usr/sbin/setcap 'CAP_SETFCAP+eip CAP_FOWNER+eip' $STREAMS_INSTALL/system/impl/bin/streams-hc
# by getting stdout from:
#/usr/sbin/getcap $STREAMS_INSTALL/system/impl/bin/streams-hc
# and checking for 'CAP_SETFCAP+eip' and 'CAP_FOWNER+eip'

step "registering Streams domain '$domain' as a Linux system service ..."
sudo STREAMS_INSTALL=$STREAMS_INSTALL $STREAMS_INSTALL/bin/streamtool registerdomainhost -d $domain --application --management --zkconnect $zkconnect || die "sorry, could not register Streams domain '$domain', $?"

step "starting Streams domain '$domain' ..."
streamtool startdomain -d $domain || die "sorry, could not start Streams domain '$domain', $?"

step "adding users to Streams domain '$domain' ..."
streamtool adduserdomainrole -d $domain DomainAdministrator $administrator || die "sorry, could not add administrator to Streams domain '$domain', $?"
streamtool adduserdomainrole -d $domain DomainUser $USER || die "sorry, could not add user to Streams domain '$domain', $?"
streamtool lsdomainrole -d $domain

step "getting service URLs for Streams domain '$domain' ..."
streamtool getjmxconnect -d $domain || die "sorry, could not domain service URL for Streams domain '$domain', $?"
streamtool geturl -d $domain || die "sorry, could not get Streams console URL for Streams domain '$domain', $?"

step "making Streams instance '$instance' ..."
streamtool mkinstance -i $instance -d $domain \
--hosts "$hostname" \
--property instanceTrace.defaultLevel=info \
--property instanceTrace.maximumFileCount=10 \
--property instanceTrace.maximumFileSize=1000000 \
--property instance.canSetPeOSCapabilities=true \
--property instance.runAsUser=$USER \
--property instance.applicationBundlesPath=/tmp/Streamsg-$instance\@$USER \
|| die "Sorry, could not create Streams instance '$instance', $?"

step "starting Streams instance '$instance' ..."
streamtool startinstance -i $instance -d $domain || die "Sorry, could not start Streams instance '$instance', $?" 

exit 0


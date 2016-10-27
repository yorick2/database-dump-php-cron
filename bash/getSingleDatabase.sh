#!/usr/bin/bash

outputFolder="databases"
configFile="sites.ini";

eval userDir=~$(whoami); # get user folder location

# make paths relative to script
if [[ ${outputFolder} != /* ]]; then
    outputFolder="${userDir}"
fi
if [[ ${configFile} != /* ]]; then
    configFile=${scriptDir}/${configFile}
fi

errors=''

_SECTIONS=`cat ${configFile} | grep -o -P "\[([a-zA-Z0-9-._ ]+)\]" | tr -d [] | sed ':a;N;$!ba;s/\n/ /g'`

ini_parser() {
    FILE=$1
    SECTION=$2
    eval $(sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
    -e 's/[;#].*$//' \
    -e 's/[[:space:]]*$//' \
    -e 's/^[[:space:]]*//' \
    -e "s/^\(.*\)=\([^\"']*\)$/\1=\"\2\"/" \
    < $FILE \
    | sed -n -e "/^\[$SECTION\]/I,/^\s*\[/{/^[^;].*\=.*/p;}")
}

sectionsArray=( ${_SECTIONS} )

echo 'use sites.ini for details (y/n)'
read useSitesIni

if [ "${useSitesIni}" = "y" ] ; then
    echo 'site reference'
    read sec
    # get info from ini file
    ini_parser ${configFile} ${sec};
else
    echo 'host?'
    read host
    echo 'user?'
    read user
fi

siteLogin="${user}@${host}"

sshReply=$(ssh  -o BatchMode=yes ${siteLogin} 'echo true');
if [ "${sshReply}" != "true" ] ; then
    echo "ssh-copy-id"
    sshReply=$( ssh-copy-id ${siteLogin} )
    if [ -z "${sshReply}" ] ; then
        exit
    fi
fi

catScript=$(cat dumpMagentoDatabase.sh)

echo '[${sec}]'
if [ -z ${docRoot} ] ; then
    ssh ${siteLogin} "url=${host} && siteRootTest=true && ${catScript}"
else
    ssh ${siteLogin} "url=${host} && siteRootTest=true && magentoPath=${docRoot} && ${catScript}"
    unset docRoot
fi


#!/usr/bin/env bash
outputFolder="databases"
configFile="sites.ini";

# script location
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# make paths relative to script
if [[ ${outputFolder} != /* ]]; then
    outputFolder=${scriptDir}/${outputFolder}
fi
if [[ ${configFile} != /* ]]; then
    configFile=${scriptDir}/${configFile}
fi

unset docRoot

echo "site url?"
read host
host="${host#http://}";
host="${host#https://}";
host="${host%/}";
if [ -f ${configFile} ]; then
    greppedUrl=$(grep "^[[:space:]]*host[[:space:]][[:space:]]*=[[:space:]][[:space:]]*${host}[[:space:]]*$" < ${configFile})
    if [ ! -z "${greppedUrl}" ] ; then
        echo "url already used"
        exit
    fi
fi
echo "ssh user?"
read user
echo "site name"
read name

siteLogin="${user}@${host}"

catScript=$(cat ${scriptDir}/dumpMagentoDatabase.sh)
sshReply=$( ssh ${siteLogin} "url=${host} && siteRootTest=true && ${catScript}")

greppedSshReply=$(echo "${sshReply}" | grep -i "Connection refused")
if [ !  -z "${greppedSshReply}" ] ; then
   exit
fi

greppedSshReply=$(echo "${sshReply}" | grep "Document root not set")
if [ !  -z "${greppedSshReply}" ] ; then
    echo "Document root not set"
    echo "Document root?"
    read docRoot
    exit
else
    echo ${sshReply} | grep -oe "magentoPath[[:space:]]*=[[:space:]]*[^[:space:]]*"
fi

echo "test download? (y/n)"
read testDownload
if [ "${testDownload}" = "y" ] ; then
    echo "running test download"

    echo 'creating databases'
	if [ -z ${docRoot} ] ; then
		sshReply=$( ssh ${siteLogin} "url=${host} && ${catScript}" )
	else
		sshReply=$( ssh ${siteLogin} "url=${host} && magentoPath=${docRoot} && ${catScript}" )
		unset docRoot
	fi

    sshReplyLastLine=$( echo "${sshReply}" | sed -e '$!d')

    if [ "$sshReplyLastLine" = "Finished" ] ; then
        if [ ! -d "${outputFolder}" ] ; then
            mkdir -p ${outputFolder}
        else
            if [ "$(ls ${outputFolder})" ]; then
                # Unfortunately, test -f doesn't support multiple file
                for i in "${outputFolder}/${host}*tar.gz" ; do test -f "$i" && rm "${outputFolder}/${host}*tar.gz" && break ; done # Unfortunately, test -f doesn't support multiple file
            fi
        fi
        if [ ! -w "${outputFolder}" ] ; then
            echo "${outputFolder} is not writable"
            exit
        fi
        echo downloading
        rsyncReply=$(rsync -ahz ${siteLogin}:/tmp/databases/* ${outputFolder}  && echo "Done" )
        if [ "${rsyncReply}" = "Done" ] ; then
             echo "[${host}]" >> ${configFile}
             echo "user = ${user}" >> ${configFile}
             echo "host = ${host}" >> ${configFile}
             if [ ! -z "${docRoot}" ] ; then
                echo "docRoot = ${docRoot}" >> ${configFile}
             fi
        else
            echo "error: rsync failed"
        fi
    else
        errors="${errors}\n${host}: ${sshReplyLastLine}"
        echo ${errors}
        exit
    fi
else
    echo "[${host}]" >> ${configFile}
    echo "user = ${user}" >> ${configFile}
    echo "host = ${host}" >> ${configFile}
fi


echo "---------------------------"
echo "Successfully added new site"
echo "---------------------------"
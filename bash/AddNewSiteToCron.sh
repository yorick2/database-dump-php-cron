#!/usr/bin/env bash
outputFolder="./databases"
configFile="sites.ini";

echo "site url?"
read host
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

catScript=$(cat dumpMagentoDatabase.sh)
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
    echo "[${host}]" >> ${configFile}
    echo "user = ${user}" >> ${configFile}
    echo "host = ${host}" >> ${configFile}
    echo "docRoot = ${docRoot}" >> ${configFile}
    exit
else
    echo ${sshReply} | grep -oe "magentoPath[[:space:]]*=[[:space:]]*[^[:space:]]*"
fi

echo "test download? (y/n)"
read testDownload
if [ "${testDownload}" = "y" ] ; then
    echo "running test download"

    sshReply=$(ssh ${siteLogin} "url=${host} && ${catScript}")
    sshReplyLastLine=$( echo "${sshReply}" | sed -e '$!d')

    if [ "$sshReplyLastLine" = "Finished" ] ; then
        if [ ! -d "${outputFolder}" ] ; then
            mkdir -p ${outputFolder}
        else
            if [ "$(ls ${outputFolder})" ]; then
                rm ${outputFolder}/${host}*tar.gz
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
#!/usr/bin/env bash
outputFolder="./databases"
configFile="sites.ini";

echo "site url?"
read url
greppedUrl=$(grep "^[[:space:]]*host[[:space:]][[:space:]]*=[[:space:]][[:space:]]*${url}[[:space:]]*$" < ${configFile})
if [ ! -z "${greppedUrl}" ] ; then
    echo "url already used"
    exit
fi
echo "ssh user?"
read user
echo "site name"
read name

siteLogin="${user}@${host}"

catScript=$(cat dumpMagentoDatabase.sh)
sshReply=$( ssh ${siteLogin} "url=${host} && siteRootTest=true && ${catScript}")

x=$(echo "${sshReply}" | grep "Document root not set")
if [ !  -z "$x" ] ; then
    echo "Document root not set"
    echo "Document root?"
    read docRoot
    echo "[${url}]" >> ${configFile}
    echo "user = ${user}" >> ${configFile}
    echo "host = ${url}" >> ${configFile}
    echo "docRoot = ${docRoot}" >> ${configFile}
    exit
else
    echo ${sshReply} | grep "magentoPath[[:space:]]*="
fi

echo "test download? (y/n)"
read testDownload
if [ "${testDownload}" = "y" ] ; then
    sshReply=$(ssh ${siteLogin} "url=${host} && ${catScript}")
    sshReplyLastLine=$( echo "${sshReply}" | sed -e '$!d')

    if [ "$sshReplyLastLine" = "Finished" ] ; then
        if [ ! -d "${outputFolder}" ] ; then
            mkdir --p ${outputFolder}
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
        rsyncReply=$(rsync -ahz ${siteLogin}:/tmp/databases/* ${outputFolder})
        echo ${rsyncReply}
        # if [] ; then  ##### <<<<<<------ needs work
        #     echo "[${url}]" >> ${configFile}
        #     echo "user = ${user}" >> ${configFile}
        #     echo "host = ${url}" >> ${configFile}
        # fi
    else
        errors="${errors}\n${url}: ${sshReplyLastLine}"
        echo $errors
    fi
else
    echo "[${url}]" >> ${configFile}
    echo "user = ${user}" >> ${configFile}
    echo "host = ${url}" >> ${configFile}
fi

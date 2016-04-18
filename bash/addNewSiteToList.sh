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

random=$(( $RANDOM % 4 ))
if [ "${random}" = "1" ] ; then
   echo '-- monty python mode ---'
   echo 'What... is your name?'
   read x
   if [ -z "${x}" ] ; then
       echo "Auuuuuuuugh"
       exit
   fi
   echo 'What... is your quest?'
   read x
   if [ -z "${x}" ] ; then
       echo "Auuuuuuuugh"
       exit
   fi
   echo 'What... is the air-speed velocity of an unladen swallow?'
   read x
   if [ -z "${x}" ] ; then
       echo "Auuuuuuuugh"
       exit
   else
       echo "How do you know so much about swallows?"
   fi
fi

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

if [ -z "${host}" ] ; then
   exit
fi
if [ -z "${user}" ] ; then
   exit
fi
if [ -z "${name}" ] ; then
   name="${host}"
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

catScript=$(cat ${scriptDir}/dumpMagentoDatabase.sh)
sshReply=$( ssh ${siteLogin} "url=${host} && siteRootTest=true && ${catScript}")

greppedSshReply=$(echo "${sshReply}" | grep -i "Connection refused")
if [ !  -z "${greppedSshReply}" ] ; then
   echo 'connection refused'
   exit
fi

greppedSshReply=$(echo "${sshReply}" | grep "Document root not found")
if [ !  -z "${greppedSshReply}" ] ; then
    echo "Web document root not found"
    echo "Web document root?"
    read docRoot
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
            if ls ${outputFolder}/${host}*tar.gz 1> /dev/null 2>&1; then
                echo "removing old files from ${outputFolder}"
                rm ${outputFolder}/${host}*tar.gz
            else
                echo "${outputFolder} is empty"
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
    if [ ! -z "${docRoot}" ] ; then
        echo "docRoot = ${docRoot}" >> ${configFile}
    fi
fi


echo "---------------------------"
echo "Successfully added new site"
echo "---------------------------"
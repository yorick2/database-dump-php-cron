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
if [ ! -z ${docRoot} ]; then
    _docRoot="&& magentoPath=${docRoot} "
fi

greppedSshReply=$( ssh ${siteLogin} "url=${host} ${_docRoot} && siteRootTest=true && ${catScript}" | grep "tmp folder is not writable")
if [ !  -z "${greppedSshReply}" ] ; then
    echo 'standard tmp folder not writable'
    echo 'please provide a location on the remote dev server to dump the databases'
    read remoteTmpLocation
fi
if [ ! -z ${remoteTmpLocation} ]; then
    _tmpFolder="&& folderPath=${remoteTmpLocation} "
fi




echo "test download? (y/n)"
read testDownload
if [ "${testDownload}" = "y" ] ; then
    echo "running test download"

    # send command to remote server via ssh
    echo 'creating databases'
    sshReply=$( ssh ${siteLogin} "url=${host} ${_tmpFolder} ${_docRoot} && ${catScript}" )

    sshReplyLastLine=$( echo "${sshReply}" | sed -e '$!d')

    if [ "$sshReplyLastLine" = "Finished" ] ; then
        if [ ! -d "${outputFolder}" ] ; then
            mkdir -p ${outputFolder}
        else
            if ls ${outputFolder}/${host}*tar.gz 1> /dev/null 2>&1; then
                echo "removing old files from ${outputFolder}"
                rm ${outputFolder}/${host}*tar.gz
            else
                echo "${outputFolder} has no databases from this url"
            fi
        fi
        if [ ! -w "${outputFolder}" ] ; then
            echo "${outputFolder} is not writable"
            exit
        fi
        echo downloading
        if [ -z ${remoteTmpLocation} ]; then
            remoteTmpLocation="/tmp/databases/${host}"
        fi
        rsyncReply=$(rsync -ahz ${siteLogin}:${remoteTmpLocation}/*.txt ${outputFolder}  && rsync -ahz ${siteLogin}:${remoteTmpLocation}/*.tar.gz ${outputFolder}  && echo "Done" )
        if [ "${rsyncReply}" = "Done" ] ; then 
          echo "[${host}]" >> ${configFile}
          echo "user = ${user}" >> ${configFile}
          echo "host = ${host}" >> ${configFile}
          if [ ! -z "${docRoot}" ] ; then
              echo "docRoot = ${docRoot}" >> ${configFile}
          fi
          if [ ! -z "${remoteTmpLocation}" ] ; then
              echo "tmpFolder = ${remoteTmpLocation}" >> ${configFile}
          fi
        else
            echo "error: rsync failed"
        fi
    else
        errors="${errors}\n${host}: ${sshReplyLastLine}"
        echo ${errors}
        exit
    fi

    unset docRoot
    unset remoteTmpLocation
else
    echo "[${host}]" >> ${configFile}
    echo "user = ${user}" >> ${configFile}
    echo "host = ${host}" >> ${configFile}
    if [ ! -z "${docRoot}" ] ; then
        echo "docRoot = ${docRoot}" >> ${configFile}
    fi
    if [ ! -z "${remoteTmpLocation}" ] ; then
        echo "tmpFolder = ${remoteTmpLocation}" >> ${configFile}
    fi
fi


echo "---------------------------"
echo "Successfully added new site"
echo "---------------------------"
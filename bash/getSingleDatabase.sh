#!/usr/bin/bash

outputFolder="databases"
configFile="sites.ini";

tmpFolder=''; # temp folder on the remote server

# script location
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# make paths relative to script
if [[ ${outputFolder} != /* ]]; then  #if doesn't start with /
    outputFolder="${scriptDir}/${outputFolder}"
fi
if [[ ${configFile} != /* ]]; then  #if doesn't start with /
    configFile="${scriptDir}/${configFile}"
fi

# siteLogin (string)
testSshConnection () {
    local testSshConnection=$( ( ssh ${siteLogin} "echo true" ) & sleep 10 ; kill $! 2>/dev/null; )
    if [ "${testSshConnection}" != "true" ]; then
        echo 'ssh connection failed'
        unset _truncateRewrites
        unset docRoot
        unset _docRoot
        unset tmpFolder
        unset _tmpFolder
        unset errors
        continue
    fi
}

# siteLogin (string)
# host (string)
# outputFolder (string)
# tmpFolder (string)
# scriptDir (string)
# docRoot (string) optional
# truncateRewrites (string) optional
getSingleSiteDatabases () {
    # get contents of script to run on remote server
	catScript=$(cat ${scriptDir}/dumpMagentoDatabase.sh)

    if [ "${truncateRewrites}" = "true" ]; then
        _truncateRewrites="&& truncateRewrites=true"
        echo 'ignoring rewrites table'
    fi

    if [ -z ${tmpFolder} ]; then
        tmpFolder="/tmp/databases/${host}"
    fi
    _tmpFolder="&& folderPath=${tmpFolder} "
    if [ ! -z ${docRoot} ]; then
        _docRoot="&& magentoPath=${docRoot} "
    fi

    # send command to remote server via ssh
    echo 'creating databases'
    local sshReply=$( ssh ${siteLogin} "url=${host} ${_tmpFolder} ${_truncateRewrites} ${_docRoot} && ${catScript}" )

    #	# debug code, for testing remote server code
    #	echo '-----------------------'
    #	echo ${sshReply}
    #	echo '-----------------------'

    local sshReplyLastLine=$( echo "${sshReply}" | sed -e '$!d')
    # if finished successfully get new database
    if [ "${sshReplyLastLine}" = "Finished" ] ; then
        if [ ! -d "${outputFolder}" ] ; then
            mkdir -p ${outputFolder}
        fi
        if [ ! -w "${outputFolder}" ] ; then
            echo "${outputFolder} is not writable"
            exit
        fi
        echo downloading
        rsync -ahz ${siteLogin}:${tmpFolder}/*.tar.gz ${outputFolder}
        rsync -ahz ${siteLogin}:${tmpFolder}/*.txt ${outputFolder}

        moveBackups

    else
        # echo error
        echo "${sshReplyLastLine}"
        # print error into log file
        errors="${host}: ${sshReplyLastLine}"
        printf "${errors}\n" >> ${scriptDir}/dbDumpErrors.log
    fi
}

# siteLogin (string)
function runSshCopyId(){
    sshReply=$(ssh  -o BatchMode=yes ${siteLogin} 'echo true');
    if [ "${sshReply}" != "true" ] ; then
        echo "copy ssh key onto server (y/n) [n] ?"
        read isSshCopyId
        if [ "${isSshCopyId}" = "y" ] ; then
            sshReply=$( ssh-copy-id ${siteLogin} )
            if [ -z "${sshReply}" ] ; then
                exit
            fi
        fi
    fi
}

# check if it can find the web root on the server and if cant it will ask for it
# scriptDir (string)
# siteLogin (string)
# host (string)
# return docRoot (string)
function getDocRoot(){
    catScript=$(cat "${scriptDir}/dumpMagentoDatabase.sh")
    sshReply=$(ssh ${siteLogin} "url=${host} && siteRootTest=true && ${catScript}")

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
}


errors=''

if [ -r ${configFile} ] ; then
    _SECTIONS=`cat ${configFile} | grep -o -P "\[([a-zA-Z0-9-._ ]+)\]" | tr -d [] | sed ':a;N;$!ba;s/\n/ /g'`
fi;
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

useSitesIni=''
while [[ "${useSitesIni}" != "y"  &&  "${useSitesIni}" != "n" ]] ; do
    echo 'use sites.ini for details (y/n)'
    read useSitesIni
    if [ "${useSitesIni}" = "y" ] ; then
        echo 'site reference'
        read sec
        # get info from ini file
        ini_parser ${configFile} ${sec};
    elif [ "${useSitesIni}" = "n" ] ; then
        echo 'host?'
        read host
        echo 'user?'
        read user
    fi
    if [[ "${useSitesIni}" != "y"  &&  "${useSitesIni}" != "n" ]] ; then
        echo "Answer not recognised. Please try again."
    fi;
done

siteLogin="${user}@${host}"

runSshCopyId

testSshConnection

if [ -z docRoot ] ; then
    getDocRoot
fi

getSingleSiteDatabases

unset _truncateRewrites
unset docRoot
unset _docRoot
unset tmpFolder
unset _tmpFolder
unset errors
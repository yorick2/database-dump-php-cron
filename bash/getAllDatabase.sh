#!/bin/bash
outputFolder="databases"
configFile="sites.ini";

if [ ! -z "${1}"  ] ; then
    testSectionName="${1}" # the name of the site to test in [] from the sites.ini file
    echo "testing for ${1}"
fi

# script location
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# make paths relative to script
if [[ ${outputFolder} != /* ]]; then
    outputFolder=${scriptDir}/${outputFolder}
fi
if [[ ${configFile} != /* ]]; then
    configFile=${scriptDir}/${configFile}
fi

errors=''

if [ ! -e "${configFile}" ] ; then
    echo "${configFile} config file dosnt exist";
    exit;
else
    if [ ! -r "${configFile}" ] ; then
        echo "${configFile} config file isnt readable";
        exit;
    fi
fi


if [ -z "${testSectionName}" ]; then
    _SECTIONS=`cat ${configFile} | grep -o -P "\[([a-zA-Z0-9-._ ]+)\]" | tr -d [] | sed ':a;N;$!ba;s/\n/ /g'`
else
    _SECTIONS="${testSectionName}"
fi

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

# remove old log file
rm ${scriptDir}/dbDumpErrors.log

# A sections array that we'll loop through
for SEC in $_SECTIONS; do
    echo [${SEC}]
    # get info from ini file
    ini_parser ${configFile} ${SEC};

	siteLogin="${user}@${host}"

    # get contents of script to run on remote server
	catScript=$(cat ${scriptDir}/dumpMagentoDatabase.sh)

    if [ "${truncateRewrites}" = "true" ]; then
        _truncateRewrites="&& truncateRewrites=true"
        echo 'ignoring rewrites table'
    fi

    # send command to remote server via ssh
    echo 'creating databases'
	if [ -z ${docRoot} ] ; then
		sshReply=$( ssh ${siteLogin} "url=${host} $_truncateRewrites && ${catScript}" )
	else
		sshReply=$( ssh ${siteLogin} "url=${host} $_truncateRewrites && magentoPath=${docRoot} && ${catScript}" )
		unset docRoot
	fi


#	# debug code, for testing remote server code
#	echo '-----------------------'
#	echo ${sshReply}
#	echo '-----------------------'

	sshReplyLastLine=$( echo "${sshReply}" | sed -e '$!d')
    # if finished successfully get new database
    if [ "$sshReplyLastLine" = "Finished" ] ; then
        if [ ! -d "${outputFolder}" ] ; then
            mkdir -p ${outputFolder}
        else
            # remove old database if exists
            if ls ${outputFolder}/${host}*tar.gz 1> /dev/null 2>&1; then
                echo "removing old files for ${host} site from ${outputFolder}"
                rm ${outputFolder}/${host}*tar.gz
            else
                echo "no need to empty ${outputFolder}, it dosnt have any files from ${host}"
            fi
        fi
        if [ ! -w "${outputFolder}" ] ; then
            echo "${outputFolder} is not writable"
            exit
        fi
        echo downloading
        rsync -ahz ${siteLogin}:/tmp/databases/* ${outputFolder}
    else
        # echo error
        echo "${sshReplyLastLine}"
        # print error into log file
        errors="${host}: ${sshReplyLastLine}"
        printf "${errors}\n" >> ${scriptDir}/dbDumpErrors.log
    fi
done


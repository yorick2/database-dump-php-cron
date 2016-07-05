#!/bin/bash
outputFolder="databases"
configFile="sites.ini";
numberBackups=7;

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
if [ -w ${scriptDir}/dbDumpErrors.log ]; then
    rm ${scriptDir}/dbDumpErrors.log
fi

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

    if [ -z ${tmpFolder} ]; then
        tmpFolder="/tmp/databases/${host}"
    fi
    _tmpFolder="&& folderPath=${tmpFolder} "
    if [ ! -z ${docRoot} ]; then
        _docRoot="&& magentoPath=${docRoot} "
    fi

    # send command to remote server via ssh
    echo 'creating databases'
    sshReply=$( ssh ${siteLogin} "url=${host} ${_tmpFolder} ${_truncateRewrites} ${_docRoot} && ${catScript}" )

#	# debug code, for testing remote server code
#	echo '-----------------------'
#	echo ${sshReply}
#	echo '-----------------------'

	sshReplyLastLine=$( echo "${sshReply}" | sed -e '$!d')
    # if finished successfully get new database
    if [ "$sshReplyLastLine" = "Finished" ] ; then
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
        fileRef="${host}-magento"
        date=`date +%Y-%m-%d`;
        # check magento db file exists and has size > 0
        if [ -s "${outputFolder}/${fileRef}--${date}.tar.gz" ] ; then
            if [ ${numberBackups} -gt 0 ] ; then
                # check if multiple magento db's in the folder for this host
                if ls ${outputFolder}/${host}-*tar.gz 1> /dev/null 2>&1 ; then

                    echo "moving backups"
                    COUNTER=${numberBackups};

                    rmRegex=${outputFolder}/backupFolder${COUNTER}/${host}*.tar.gz
                    if ls ${rmRegex} 1> /dev/null 2>&1 ; then
                        rm ${rmRegex}
                    fi
                    rmRegex=${outputFolder}/backupFolder${COUNTER}/${host}*.txt
                    if ls ${rmRegex} 1> /dev/null 2>&1 ; then
                        rm ${rmRegex}
                    fi

                    while [  ${COUNTER} -gt 1 ]; do
                        sourceFolder=backupFolder$((${COUNTER}-1))
			            destinationFolder=backupFolder${COUNTER}
			            if [ ! -d "${outputFolder}/${destinationFolder}" ] ; then
                            mkdir -p ${outputFolder}/${destinationFolder}
                        fi
                        if [ ! -w "${outputFolder}/${destinationFolder}" ] ; then
                            echo "${outputFolder}/${destinationFolder} is not writable"
                            exit
                        fi
                        mvRegex=${outputFolder}/${sourceFolder}/${host}*.tar.gz
                        if ls ${mvRegex} 1> /dev/null 2>&1 ; then
                            mv ${mvRegex} ${outputFolder}/${destinationFolder}
                        fi
                        mvRegex=${outputFolder}/${sourceFolder}/${host}*.txt
                        if ls ${mvRegex} 1> /dev/null 2>&1 ; then
                            mv ${mvRegex} ${outputFolder}/${destinationFolder}
                        fi
                        let COUNTER=${COUNTER}-1
                    done

	                if [ ! -d "${outputFolder}/backupFolder1" ] ; then
	                    echo "mkdir -p ${outputFolder}/backupFolder1"
                        mkdir -p ${outputFolder}/backupFolder1
                    fi
                    if [ ! -w "${outputFolder}/backupFolder1" ] ; then
                        echo "${outputFolder}/backupFolder1 is not writable"
                        exit
                    fi

                    # move todays and yesterdays files into backupFolder1
                    mvRegex=${outputFolder}/${host}*.tar.gz
                    if ls ${mvRegex} 1> /dev/null 2>&1 ; then
                        mv ${mvRegex} ${outputFolder}/backupFolder1
                    fi
                    mvRegex=${outputFolder}/${host}*.txt
                    if ls ${mvRegex} 1> /dev/null 2>&1 ; then
                        mv ${mvRegex} ${outputFolder}/backupFolder1
                    fi
                    # move todays filest back
                    mvRegex=${outputFolder}/backupFolder1/${host}*${date}.tar.gz
                    if ls ${mvRegex} 1> /dev/null 2>&1 ; then
                        mv ${mvRegex} ${outputFolder}
                    fi
                    mvRegex=${outputFolder}/backupFolder1/${host}*--${date}.txt
                    if ls ${mvRegex} 1> /dev/null 2>&1 ; then
                        mv ${mvRegex} ${outputFolder}
                    fi
                    mvRegex=${outputFolder}/backupFolder1/${host}-wpsetting.txt
                    if ls ${mvRegex} 1> /dev/null 2>&1 ; then
                        mv ${mvRegex} ${outputFolder}
                    fi
                fi
            fi
        fi
    else
        # echo error
        echo "${sshReplyLastLine}"
        # print error into log file
        errors="${host}: ${sshReplyLastLine}"
        printf "${errors}\n" >> ${scriptDir}/dbDumpErrors.log
    fi

    unset _truncateRewrites
    unset docRoot
    unset _docRoot
    unset tmpFolder
    unset _tmpFolder
    unset errors
done


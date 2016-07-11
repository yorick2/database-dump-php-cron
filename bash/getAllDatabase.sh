#!/bin/bash

###### set variables #######

outputFolder="databases"
configFile="sites.ini";
numberDailyBackups=7;
numberWeeklyBackups=10;
numberMonthlyBackups=6;

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

###### get config #######

if [ ! -e "${configFile}" ] ; then
    echo "${configFile} config file dosnt exist";
    exit;
else
    if [ ! -r "${configFile}" ] ; then
        echo "${configFile} config file isnt readable";
        exit;
    fi
fi

###### read config ######


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

###### set functions #######


removeFileIfExists () {
    if [ -z "${1}" ] ; then
        echo 'missing variable moveFiles function';
        echo 'missing variables:'
        echo 'bash removeFileIfExists.sh <<<file or folder>>>';
        exit
    fi
    if ls "${1}" 1> /dev/null 2>&1 ; then
        rm "${1}"
    fi
}

moveFileIfExists () {
    if [ -z "${1}" ] || [ -z "${2}" ] ; then
        echo 'missing variable moveFiles function';
        echo 'missing variables:'
        echo 'bash moveFileIfExists.sh <<<source>> <<<destination>>>';
        echo 'source: regex filepath, filepath, folderpath'
        echo 'destination: destination folder'
        exit
    fi
    if ls "${1}" 1> /dev/null 2>&1 ; then
        mv "${1}" "${2}"
    fi
}

moveBackups () {
    if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] ; then
        echo 'missing variable moveFiles function'
        echo 'missing variables:'
        echo 'bash moveFiles.sh <<<old folder>>> <<<newFolderPrefix>>> <<<date>>> or '
        echo 'bash moveFiles.sh <<<old folder>>> <<<newFolderPrefix>>> <<<date>>> <<<no. of backups>>> '
        echo 'oldFolder: full folder path to old folder'
        echo 'newFolderPrefix: full folder path.'
        echo 'date: date in format Y-m-d`;'
        echo 'no. of backups: (int) the number of backups to keep'
        echo 'e.g. /home/myuser/dbDumpScript/monthly which will mean the script will create and use /home/myuser/dbDumpScript/monthly1 /home/myuser/dbDumpScript/monthly2 ....'
        exit
    fi

    local oldFolder="${1}"
    local newFolderPrefix="${2}"
    local date="${3}"

    echo "moving backups"

    if [ -z "${4}" ] ; then
        local numberOfBackups="${4}"
    else
        local numberOfBackups="3"
    fi

    if [ "${numberOfBackups}" -gt "0" ] ; then
        local COUNTER="${numberOfBackups}";

        # remove unwanted oldest backup
        removeFileIfExists ${newFolderPrefix}${COUNTER}/${host}*.tar.gz
        removeFileIfExists ${newFolderPrefix}${COUNTER}/${host}*.txt

        # move files to new folders
        while [  "${COUNTER}" -gt "0" ]; do
            if [ "${COUNTER}" = "1" ] ; then
                local sourceFolder=${oldFolder}
            else
                local sourceFolder=${newFolderPrefix}$((${COUNTER}-1))
            fi
            local destinationFolder=${newFolderPrefix}${COUNTER}

            if [ ! -d "${destinationFolder}" ] ; then
                mkdir -p ${destinationFolder}
            fi
            if [ ! -w "${destinationFolder}" ] ; then
                echo "${destinationFolder} is not writable"
                exit
            fi

            moveFileIfExists ${sourceFolder}/${host}*.tar.gz ${destinationFolder}
            moveFileIfExists ${sourceFolder}/${host}*.txt ${destinationFolder}
            local let COUNTER=$((COUNTER-1))
        done

        # move newest files back into folder
        moveFileIfExists ${newFolderPrefix}1/${host}*${date}.tar.gz ${oldFolder}
        moveFileIfExists ${newFolderPrefix}1/${host}*--${date}.txt ${oldFolder}
        moveFileIfExists ${newFolderPrefix}1/${host}-wpsetting.txt ${oldFolder}
    fi
}

######  #######

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
            # check if multiple magento db's in the folder for this host
            if ls ${outputFolder}/${host}-*tar.gz 1> /dev/null 2>&1 ; then

                moveBackups "${outputFolder}" "${outputFolder}/dailyBackup" "${date}" "${numberDailyBackups}"

                LANG=C DOW=$(date +"%a") # todays, day of week e.g. Tue
                if [ "${DOW}" = "Sun" ] ; then
                    moveBackups "${outputFolder}/dailyBackup${numberDailyBackups}" "${outputFolder}/weeklyBackup" "${date}" "${numberWeeklyBackups}"
                fi

                dateOfMonth=$(date +"%d") # day of month (e.g, 01)
                if [ "${dateOfMonth}" = "01" ] ; then
                    moveBackups "${outputFolder}/weeklyBackup${numberDailyBackups}" "${outputFolder}/monthlyBackup" "${date}" "${numberMonthlyBackups}"
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


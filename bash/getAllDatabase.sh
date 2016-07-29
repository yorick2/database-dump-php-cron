#!/bin/bash

###### set variables #######

outputFolder="databases"
configFile="sites.ini";
numberDailyBackups=2; #7;
numberWeeklyBackups=2; #10;
numberMonthlyBackups=2; #6;

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

# 1 (string) file or folder location, allows use of *'s etc
removeFileIfExists () {
    if [ -z "${1}" ] ; then
        echo 'missing variable moveFiles function';
        echo 'missing variables:'
        echo 'bash removeFileIfExists <<<file or folder>>>';
        exit
    fi
    if ls ${1} 1> /dev/null 2>&1 ; then
        rm ${1}
    fi
}

# 1 (string) source file or folder location, allows use of *'s etc
# 2 (string) destination folder location
moveFileIfExists () {
    if [ -z "${1}" ] || [ -z "${2}" ] ; then
        echo 'moveFiles function missing variable';
        echo 'missing variables:'
        echo 'bash moveFileIfExists <<<source>> <<<destination>>>';
        echo 'source: regex filepath, filepath, folderpath'
        echo 'destination: destination folder'
        exit
    fi

    echo "mv ${1} ${2}" #######>>>>deleteme
    if ls ${1} 1> /dev/null 2>&1 ; then
        mv ${1} ${2}
    fi
}

# move backups between folders and remove no longer required files. Works for one destination folder prefix.
# e.g. moving files foir the daily backups is run using
# moveBackupSet "${outputFolder}" "${outputFolder}/dailyBackup" "${date}" "${numberDailyBackups}"
#
# 1 (string) source folder location
# 2 (string) destination folder location prefix,
# 3 (string) [optional] date, used in file naming
# 4 (int) number of backups to keep
moveBackupSet () {
    if [ -z "${1}" ] || [ -z "${2}" ] ; then
        echo 'missing variable moveFiles function'
        echo 'missing variables:'
        echo 'bash moveBackupSet <<<old folder>>> <<<newFolderPrefix>>> or '
        echo 'bash moveBackupSet <<<old folder>>> <<<newFolderPrefix>>> <<<date>>> or '
        echo 'bash moveBackupSet <<<old folder>>> <<<newFolderPrefix>>> <<<date>>> <<<no. of backups>>> '
        echo 'oldFolder: full folder path to old folder'
        echo 'newFolderPrefix: full folder path.'
        echo 'e.g. /home/myuser/dbDumpScript/monthly which will mean the script will create and use /home/myuser/dbDumpScript/monthly1 /home/myuser/dbDumpScript/monthly2 ....'
        echo 'date: date in format Y-m-d`;'
        echo 'no. of backups: (int) the number of backups to keep'
        exit
    fi

    local oldFolder="${1}"
    local newFolderPrefix="${2}"

     if [ -z "${3}" ] ; then
        local date=`date +%Y-%m-%d`;
    else
        local date="${3}"
    fi

    if [ -z "${4}" ] ; then
        local numberOfBackups="3"
    else
        local numberOfBackups="${4}"
    fi

    if [ "${numberOfBackups}" -gt "0" ] ; then

        echo "moving backups"

        local COUNTER="${numberOfBackups}";

        # remove unwanted oldest backup
        removeFileIfExists "${newFolderPrefix}${COUNTER}/${host}*.tar.gz"
        removeFileIfExists "${newFolderPrefix}${COUNTER}/${host}*.txt"

        # move files to new folders
        while [  "${COUNTER}" -gt "0" ]; do
            if [ "${COUNTER}" = "1" ] ; then
                local sourceFolder="${oldFolder}"
            else
                local sourceFolder=${newFolderPrefix}$((${COUNTER}-1))
            fi
            local destinationFolder="${newFolderPrefix}${COUNTER}"

            if [ ! -d "${destinationFolder}" ] ; then
                mkdir -p "${destinationFolder}"
            fi
            if [ ! -w "${destinationFolder}" ] ; then
                echo "${destinationFolder} is not writable"
                exit
            fi

            moveFileIfExists "${sourceFolder}/${host}*.tar.gz" "${destinationFolder}"
            moveFileIfExists "${sourceFolder}/${host}*.txt" "${destinationFolder}"
            local let COUNTER=$((COUNTER-1))
        done
    fi
}

# moves all the backups
#
# host (string) host url
# outputFolder (string)
# numberDailyBackups (int)
# numberWeeklyBackups (int)
# numberMonthlyBackups (int)
moveBackups () {
    local fileRef="${host}-magento"
    local date=`date +%Y-%m-%d`;
    echo "${outputFolder}/${fileRef}--${date}.tar.gz"  #######>>>>deleteme
    # check magento db file exists and has size > 0
    if [ -s "${outputFolder}/${fileRef}--${date}.tar.gz" ] ; then
        # check if multiple magento db's in the folder for this host
        if ( ls ${outputFolder}/${host}-*tar.gz | grep "${date}" ) 1> /dev/null 2>&1; then
            echo "moving backups"

            dateOfMonth=$(date +"%d") # day of month (e.g, 01)
            if [ "${dateOfMonth}" = "29" ] ; then
                echo "moveBackupSet" "${outputFolder}/weeklyBackup${numberWeeklyBackups}" "${outputFolder}/monthlyBackup" "${date}" "${numberMonthlyBackups}" #######>>>>deleteme
                moveBackupSet "${outputFolder}/weeklyBackup${numberWeeklyBackups}" "${outputFolder}/monthlyBackup" "${date}" "${numberMonthlyBackups}"
            fi

            LANG=C DOW=$(date +"%a") # todays, day of week e.g. Tue
            if [ "${DOW}" = "Fri" ] ; then
                echo "moveBackupSet" "${outputFolder}/dailyBackup${numberDailyBackups}" "${outputFolder}/weeklyBackup" "${date}" "${numberWeeklyBackups}" #######>>>>deleteme
                moveBackupSet "${outputFolder}/dailyBackup${numberDailyBackups}" "${outputFolder}/weeklyBackup" "${date}" "${numberWeeklyBackups}"
            fi

            echo " moveBackupSet" "${outputFolder}" "${outputFolder}/dailyBackup" "${date}" "${numberDailyBackups}" #######>>>>deleteme
            moveBackupSet "${outputFolder}" "${outputFolder}/dailyBackup" "${date}" "${numberDailyBackups}"
            if [ "${numberDailyBackups}" -gt "0" ] ; then
                # move newest files back into folder
                moveFileIfExists "${outputFolder}/dailyBackup1/${host}*${date}.tar.gz" "${oldFolder}"
                moveFileIfExists "${outputFolder}/dailyBackup1/${host}*--${date}.txt" "${oldFolder}"
                moveFileIfExists "${outputFolder}/dailyBackup1/${host}-wpsetting.txt" "${oldFolder}"
            fi

        fi
    fi
}

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
getSiteDatabases () {
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

###### Run the program  #######

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

    testSshConnection

	getSiteDatabases

    unset _truncateRewrites
    unset docRoot
    unset _docRoot
    unset tmpFolder
    unset _tmpFolder
    unset errors
done


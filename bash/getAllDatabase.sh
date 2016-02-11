#!/bin/bash
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

_SECTIONS=`cat ${configFile} | grep -o -P "\[([a-zA-Z0-9-._ ]+)\]" | tr -d [] | sed ':a;N;$!ba;s/\n/ /g'`

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


# A sections array that we'll loop through
for SEC in $_SECTIONS; do
    echo [${SEC}]
    # get info from ini file
    ini_parser ${configFile} ${SEC};

	siteLogin="${user}@${host}"

	catScript=$(cat ${scriptDir}/dumpMagentoDatabase.sh)

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
                rm ${outputFolder}/${host}*tar.gz
            fi
        fi
        if [ ! -w "${outputFolder}" ] ; then
            echo "${outputFolder} is not writable"
            exit
        fi
        echo downloading
        rsync -ahz ${siteLogin}:/tmp/databases/* ${outputFolder}
    else
        errors="${errors}\n${url}: ${sshReplyLastLine}"
    fi
done

printf "${errors}" > ${scriptDir}/dbDumpErrors.log
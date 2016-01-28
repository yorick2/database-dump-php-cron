#!/usr/bin/bash

outputFolder="./databases"
configFile="sites.ini";

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



sectionsArray=( ${_SECTIONS} )
sec=${sectionsArray[-1]}

# get info from ini file
ini_parser ${configFile} ${sec};

siteLogin="${user}@${host}"

catScript=$(cat dumpMagentoDatabase.sh)

echo [${sec}]
if [ -z ${docRoot} ] ; then
    ssh ${siteLogin} "url=${host} && siteRootTest=true && ${catScript}"
else
    ssh ${siteLogin} "url=${host} && siteRootTest=true && magentoPath=${docRoot} && ${catScript}"
    unset docRoot
fi


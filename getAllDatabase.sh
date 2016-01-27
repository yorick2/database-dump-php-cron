#!/bin/bash
outputFolder="./databases"
configFile="sites.ini";

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
    # get info from ini file
    ini_parser ${configFile} ${SEC};

	siteLogin="${user}@${host}"

	catScript=$(cat dumpMagentoDatabase.sh)
	
	if [ -z ${docRoot} ] ; then
		ssh ${siteLogin} "url=${host} && ${catScript}"
	else
		ssh ${siteLogin} "url=${host} && magentoPath=${docRoot} && ${catScript}"
		unset docRoot
	fi
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
	rsync -ahz ${siteLogin}:/tmp/databases/* ${outputFolder}
done

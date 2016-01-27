#!/bin/bash

CONFIGFILE="example.ini";

_SECTIONS=`cat ${CONFIGFILE} | grep -o -P "\[([a-zA-Z0-9-]+)\]" | tr -d [] | sed ':a;N;$!ba;s/\n/ /g'`

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
    ini_parser ${CONFIGFILE} ${SEC};

	siteLogin="${user}@${host}"

	safeDomain=${siteLogin##*@} #remove all text before the @
	safeDomain=$( echo ${safeDomain} | sed 's/[^a-zA-Z0-9_]/_/g')
	magentoPath="${!safeDomain}"
	catScript=$(cat dumpMagentoDatabase.sh)
	
	ssh ${siteLogin} "magentoPath=${DocumentRoot} && ${catScript}"

	outputFolder="./databases/${safeDomain}"
	
	if [ ! -d "${outputFolder}" ] ; then
		mkdir --p ${outputFolder}
	fi
	if [ ! -w "${outputFolder}" ] ; then
		echo "${outputFolder} is not writable"
		exit
	fi

	if [ -d "${outputFolder}" ] ; then
		rm ${outputFolder}/*
	fi
	rsync -ahz ${siteLogin}:/tmp/databases/* ${outputFolder}
done

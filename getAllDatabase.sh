#!/bin/bash

siteLoginList=( "test@example.com" "test@example2.com" )
example_com='/var/www/htdocs'
example2_com='/var/www/public_html'

for siteLogin in "${siteLoginList[@]}" ; do
	safeDomain=${siteLogin##*@} #remove all text before the @
	safeDomain=$( echo ${safeDomain} | sed 's/[^a-zA-Z0-9_]/_/g'
	magentoPath="${!safeDomain}"
	dumpScript=`cat dumpMagentoDatabase.sh`
	# or do this
	#dumpScript=$(<dumpMagentoDatabase.sh)

	ssh ${siteLogin} -t "magentoPath=${magentoPath} && ${dumpScript}"
#	ssh ${siteLogin} -t "magentoPath=${magentoPath} && ${dumpScript}"

	outputFolder="./databases/${safeDomain}"
	if [ ! -d "${outputFolder}" ] ; then
		mkdir --parents ${outputFolder}
	fi
	if [ ! -w "${outputFolder}" ] ; then
		echo "${outputFolder} is not writable"
		exit
	fi

	rsync -ahz ${siteLogin}:/tmp/databases/* ${outputFolder}
done
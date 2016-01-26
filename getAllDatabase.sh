#!/bin/bash

siteLoginList=( "test@example.com" "test@example2.com" )

# there has got to be a better way to do this
example_com='/var/www/htdocs'
example2_com='/var/www/public_html'

for siteLogin in "${siteLoginList[@]}" ; do
	safeDomain=${siteLogin##*@} #remove all text before the @
	safeDomain=$( echo ${safeDomain} | sed 's/[^a-zA-Z0-9_]/_/g')
	magentoPath="${!safeDomain}"
	catScript=$(cat dumpMagentoDatabase.sh)
	
	#ssh ${siteLogin} "magentoPath=${magentoPath} && ${catScript}"

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
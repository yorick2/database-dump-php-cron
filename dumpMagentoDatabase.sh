#!/usr/bin/env bash

eval userDir=~$(whoami); # get user folder location
magentoPath="${magentoPath/\~/${userDir}}"

if [ -z ${truncateRewrites} ]; then
	truncateRewrites=true  ######### should this set to yes by default
fi
if [ -z ${folderPath} ]; then
	folderPath='/tmp/databases'
fi

##### get web folder ####
# problem is need url to get folder to get url????
# could pass the url to this script


if [ -z ${magentoPath} ]; then
    isNginx=$(top -b -n 1|grep nginx)
    isApache=$(top -b -n 1|grep apache)
    # if apache
    if [ "${isApache}" != "" ]; then
        apacheConfFile=$( grep --files-with-matches 'ServerName.*${url}' /etc/apache2/sites-available/* )
        if [ "${apacheConfFile}" = "" ] ; then
            apacheConfFile=$( grep --files-with-matches 'ServerName.*${url}' /etc/apache2/extra/* )
        fi
        magentoPath=$( grep 'DocumentRoot' ${apacheConfFile} )
        magentoPath="/${magentoPath##* /}"
    # if nginx
    elif [ "${isNginx}" != "" ] ; then
        nginxConfFile=$( grep --files-with-matches '${url}' /etc/nginx/sites-available/* )
        magentoPath=$( grep 'root' ${nginxConfFile} )
        magentoPath="/${magentoPath##*root /}"
    else

    fi
fi

#########################

cd ${magentoPath}

dbName=$(n98-magerun.phar db:info dbname)
databaseRef="${siteUrl}-${dbName}"

date=`date +%Y-%m-%d`;
fileName="${databaseRef}-${date}.sql"
filePath="${folderPath}/${fileName}"

if [ "${truncateRewrites}"="true" ] ; then
    truncateTablesList='core_url_rewrite @development';
else
    truncateTablesList='@development';
fi

if [ ! -d "${folderPath}" ] ; then
	mkdir -p "${folderPath}"
fi

if [ ! -w "${folderPath}" ] ; then
	echo "${folderPath} is not writable"
	exit
fi

if [ ! -a "${filePath}" ] ; then
	if [ ! -e "${filePath}.lock" ] ; then
		touch "${filePath}.lock" &&
		rm "${folderPath}/${databaseRef}-*.tar.gz"
		n98-magerun.phar db:dump --strip="$truncateTablesList" ${filePath} &&
		tar -czf "${filePath}.tar.gz" --directory ${folderPath} ${fileName} &&
		rm -f "${filePath}.lock" &&
		rm ${filePath}
	fi
fi

unset magentoPath
unset folderPath
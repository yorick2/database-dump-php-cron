#!/usr/bin/env bash
if [ -z ${url} ] ; then
	if [ ! -z $1 ] ; then
		echo 'missing variables:'
		echo 'bash dumpMagentoDatabase.sh <<<url>>> or bash dumpMagentoDatabase.sh <<<url>>> <<<magentoFolder>>>>'
		exit;
	else
		url=$1
	fi
fi
if [ ! -z $2 ] ; then
	magentoPath=$2
fi

if [ -z ${siteRootTest} ] ; then
    siteRootTest="false"
fi

if [ -z ${truncateRewrites} ]; then
	truncateRewrites=true  ######### should this set to yes by default
fi
if [ -z ${folderPath} ]; then
	folderPath='/tmp/databases'
fi

##### get web folder ####
if [ -z ${magentoPath} ]; then
    isNginx=$(top -b -n 1|grep nginx)
    isApache=$(top -b -n 1|grep apache)
    # if apache
    if [ "${isApache}" != "" ]; then
        if [ -d "/etc/apache2/sites-available" ] ; then
			apacheConfFile=$( grep --files-with-matches "ServerName.*${url}" /etc/apache2/sites-available/* )
        else
	        if [ -d "/etc/apache2/etc" ] ; then
			    apacheConfFile=$( grep --files-with-matches "ServerName.*${url}" /etc/apache2/extra/* )
	        fi
	    fi
        if [ "${apacheConfFile}" != "" ]; then
    		magentoPath=$(  sed -e 's/[#].*$//' <  ${apacheConfFile} | grep 'DocumentRoot' )
        	magentoPath="${magentoPath##*DocumentRoot[[:space:]]}"
        fi
    # if nginx
    elif [ "${isNginx}" != "" ] ; then
    	if [ -d "/etc/nginx/sites-available" ] ; then
	    	nginxConfFile=$( grep --files-with-matches "${url}" /etc/nginx/sites-available/* )
	    	if [ "${nginxConfFile}" != "" ]; then
	    		magentoPath=$( sed -e 's/[#].*$//' <  ${nginxConfFile} | grep 'root ' | head -n 1 )
	        	magentoPath="${magentoPath##*root[[:space:]]}"
	        	magentoPath="${magentoPath%%;*}"
	        fi
	    fi
    fi
    if [ "${magentoPath}" = "" ] ; then
    	echo 'Document root not set';
    	exit;
    else
        echo "magentoPath=${magentoPath}"
    fi
fi

if [ "${siteRootTest}" != "true" ] ; then
    eval userDir=~$(whoami); # get user folder location
    magentoPath="${magentoPath/\~/${userDir}}"
    cd ${magentoPath}

    #### magento db dump ####
    fileRef="${url}-magento"
    date=`date +%Y-%m-%d`;
    fileName="${fileRef}--${date}.sql"
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

    if [ ! -a "${filePath%.sql}.tar.gz" ] ; then
        if [ ! -e "${filePath}.lock" ] ; then
            touch "${filePath}.lock" &&
            n98-magerun.phar db:dump --strip="$truncateTablesList" ${filePath} &&
            tar -czf "${filePath%.sql}.tar.gz" --directory ${folderPath} ${fileName}
            rm -f "${filePath}.lock"
            rm ${filePath}
        fi
    fi


    #### wordpress db dump ####
    wordpressConfigFiles=$(ls -x ./*/wp-config.php)
    for configFile in $wordpressConfigFiles; do
        wordpressFolder=$( echo "${configFile%/*}" | sed s/^[[:space:]]*[./]*// )
        fileRef="${url}-${wordpressFolder}"
        date=`date +%Y-%m-%d`
        fileName="${fileRef}--${date}.sql"
        filePath="${folderPath}/${fileName}"
        if [ ! -a "${filePath%.sql}.tar.gz" ] ; then
            if [ ! -e "${filePath}.lock" ] ; then
                dbName=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_NAME' | sed -e "s/.*,[[:space:]]'\(.*\)'.*/\1/" )
                dbUser=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_USER' | sed -e "s/.*,[[:space:]]'\(.*\)'.*/\1/" )
                dbPass=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_PASSWORD' | sed -e "s/.*,[[:space:]]'\(.*\)'.*/\1/" )
                dbHost=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_HOST' | sed -e "s/.*,[[:space:]]'\(.*\)'.*/\1/" )
                touch "${filePath}.lock" &&
                mysqldump -h ${dbHost} -u${dbUser} -p${dbPass} ${dbName} > ${filePath} &&
                tar -czf "${filePath%.sql}.tar.gz" --directory ${folderPath} ${fileName}
                rm -f "${filePath}.lock" &&
                rm ${filePath}
            fi
        fi
    done
fi

unset magentoPath
unset folderPath
#!/usr/bin/env bash
if [ -z ${url} ] ; then
	if [ -z "$1" ] ; then
		echo 'missing variables:'
		echo 'bash dumpMagentoDatabase.sh <<<url>>>'
        echo 'or bash dumpMagentoDatabase.sh <<<url>>> <<<outputFolder>>>>'
        echo 'or bash dumpMagentoDatabase.sh <<<url>>> <<<outputFolder>>>> <<<magentoFolder>>>>'
		echo
        echo 'to check if web root can be found run:'
		echo 'bash dumpMagentoDatabase.sh <<<url>>> --siteRootTest'
        echo
		exit;
	else
		url=$1
	fi
fi

if [ "$2" = "--siteRootTest"  ] ; then
    siteRootTest=true
else
    if [ -z ${folderPath} ]; then
        if [ -z "$2" ] ; then
            folderPath='/tmp/databases'
            useStandardOutputFolder='true'
        else
            folderPath="$2"
        fi
    fi
fi

if [ -z ${siteRootTest} ] ; then
    siteRootTest="false"
fi

if [ -z ${truncateRewrites} ]; then
	truncateRewrites=true  ######### should this set to yes by default
fi

if [ ! -z "$3" ] ; then
        magentoPath=$3
fi

##### get web folder ####
if [ -z ${magentoPath} ]; then
    isNginx=$(top -b -n 1|grep nginx)
    isApache=$(top -b -n 1|grep apache)
    # if apache
    if [ ! -z "${isApache}" ]; then
        if [ -d "/etc/apache2/sites-available" ] ; then
			apacheConfFile=$( grep --files-with-matches "ServerName.*${url}" /etc/apache2/sites-available/* )
        else
	        if [ -d "/etc/apache2/etc" ] ; then
			    apacheConfFile=$( grep --files-with-matches "ServerName.*${url}" /etc/apache2/extra/* )
	        fi
	    fi
        if [ ! -z "${apacheConfFile}" ]; then
    		magentoPath=$(  sed -e 's/[#].*$//' <  ${apacheConfFile} | grep 'DocumentRoot' )
        	magentoPath="${magentoPath##*DocumentRoot[[:space:]]}"
        fi
    # if nginx
    elif [ ! -z "${isNginx}" ] ; then
    	if [ -d "/etc/nginx/sites-available" ] ; then
	    	nginxConfFile=$( grep --files-with-matches "${url}" /etc/nginx/sites-available/* )
	    	echo "---$nginxConfFile---"
    		if [ "${#nginxConfFile[@]}" = "1" ] ; then # check if desired no of files
    			if [ ! -z "${nginxConfFile}" ]; then
    	    			magentoPath=$( sed -e 's/[#].*$//' <  ${nginxConfFile} | grep 'root ' | head -n 1 )
    		        	magentoPath="${magentoPath##*root[[:space:]]}"
    		        	magentoPath="${magentoPath%%;*}"
    			fi
	        fi
	    fi
    fi
    if [ -z "${magentoPath}" ] ; then
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
        if [ "$useStandardOutputFolder" = "true" ] ; then
            mkdir -p "${folderPath}"
        fi
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

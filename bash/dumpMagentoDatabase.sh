#!/usr/bin/env bash

# echo instructions if variables missing
if [ -z ${url} ] ; then
	if [ -z "$1" ] ; then
		echo 'missing variables:'
		echo 'bash dumpMagentoDatabase.sh <<<url>>>'
        echo 'or bash dumpMagentoDatabase.sh <<<url>>> <<<outputFolder>>>>'
        echo 'or bash dumpMagentoDatabase.sh <<<url>>> <<<outputFolder>>>> <<<magentoFolder>>>>'
		echo
        echo 'to check if web root can be found run:'
		echo 'bash dumpMagentoDatabase.sh --siteRootTest <<<url>>> '
        echo
        echo 'to truncate rewrites run:'
		echo 'bash dumpMagentoDatabase.sh --truncateRewrites <<<url>>> '
		echo
        echo 'to stop rewrites being truncated '
        echo 'truncateRewrites=false; Reritebash dumpMagentoDatabase.sh <<<url>>>'
		exit;
	fi
fi

##### set options #####

while test $# -gt 0; do
    case "$1" in
        --truncateRewrites)
            truncateRewrites="true"
            echo 'setting truncateRewrites to true'
            shift
            ;;
        --siteRootTest)
            siteRootTest=true
            ;;
        *)
            break
            ;;
    esac
done

if [ -z ${siteRootTest} ] ; then
    siteRootTest="false"
fi

if [ -z ${url} ] ; then
    url="${1}"
fi

if [ -z ${folderPath} ]; then
    if [ -z "$2" ] ; then
        folderPath='/tmp/databases'
    else
        folderPath="$2"
    fi
fi

if [ ! -z "$3" ] ; then
    magentoPath=$3
fi

##### find user dir #####

# define space short hand for later user
sp='[:space:]'
s='[[:space:]]'
eval userDir=~$(whoami); # get user folder location

##### get web folder ####
if [ -z ${magentoPath} ]; then
    isNginx=$(top -b -n 1|grep nginx)
    isApache=$(top -b -n 1|grep apache)
    # if apache
    if [ ! -z "${isApache}" ]; then

        # find apache directory
    	apacheConfDir1='/etc/apache2/sites-enabled'
        apacheConfDir2='/etc/apache2/extra'
    	apacheConfDir3='/etc/httpd/sites-enabled'
        apacheConfDir4='/etc/httpd/extra'
    	if [ -d "${apacheConfDir1}" ] ; then
			apacheConfDir="${apacheConfDir1}"
        elif [ -d "${apacheConfDir2}" ] ; then
	        apacheConfDir="${apacheConfDir2}"
	    elif [ -d "${apacheConfDir3}" ] ; then
	        apacheConfDir="${apacheConfDir3}"
	    elif [ -d "${apacheConfDir4}" ] ; then
	        apacheConfDir="${apacheConfDir4}"
	    fi
	    # find apache config file
        apacheConfFile=$( grep --files-with-matches "^${s}*ServerName${s}*${url}[${sp};]*$" ${apacheConfDir}/* )

	    echo "using this apache conf file: ${apacheConfFile}"
        if [ "${#apacheConfFile[@]}" = "1" ] ; then # check if desired no of files
			if [ ! -z "${apacheConfFile}" ]; then  # line needed to check not empty array of length 1
				  string=$( sed -e 's/[#].*$//' < ${apacheConfFile})
				  # add ; to EOL and put into single line
				  string=$( echo "${string}" | sed -e 's/$/;/g' | sed ':a;N;$!ba;s/\n//g' );
				  # add |'s to allow patern matching of | separeted sections
				  delimter='<${s}*VirtualHost${s}*\*:80${s}*>'
				  string=$( echo "${string}" | sed "s/${delimter}//g" );
				  delimter='<${s}*\/${s}*VirtualHost${s}*>'
				  string=$( echo "${string}" | sed -e "s/${delimter}/|/g" );
				  # return section that has our server info
				  string=$(echo "${string}" | grep -oe "[^|]*[${sp};]ServerName[${sp};][${sp};]*${url}[${sp};][^|]*")
				  # return the folderloaction
				  magentoPath=$(echo "${string}" | grep -oe "[${sp};]DocumentRoot${s}${s}*[^;]*" | sed -e "s/^[${sp};]*DocumentRoot['${sp}]*//g" | sed -e "s/['${sp}]*$//g") # | sed -e 's/"*//g' )
	        else
				numFiles=(${apacheConfDir}/*);
				numFiles=${#numFiles[@]};
				if [ "${numFiles}"="1" ] ; then
			    	apacheConfSingleFile=(${apacheConfDir}/*)
	   	    		echo "trying this apache config file: ${apacheConfSingleFile[@]}"
			    fi
		    fi
		fi
	    if [ "${#apacheConfSingleFile[@]}" = "1" ] ; then # check if desired no of files
			if [ ! -z "${apacheConfSingleFile}" ] ; then # line neededto check not empty array of length 1
	    	    string=$( sed -e 's/[#].*$//' < ${apacheConfSingleFile} )
				# find lines setting server name
	    	    hostsSetInFile=$( echo "${string}" | grep "^${s}*ServerName${s}" )
	    	    # if file dosnt set a server name then safe to assume its our file
	    	    if [ -z "$hostsSetInFile" ] ; then
					# add ; to EOL and put into single line
					string=$( echo "${string}" | sed -e 's/$/;/g' | sed ':a;N;$!ba;s/\n//g' );
					# add |'s to allow patern matching of | separeted sections
					delimter='<${s}*VirtualHost${s}*\*:80${s}*>'
					string=$( echo "${string}" | sed "s/${delimter}//g" );
					delimter='<${s}*\/${s}*VirtualHost${s}*>'
					string=$( echo "${string}" | sed -e "s/${delimter}/|/g" );
					# return section that has our server info
					string=$(echo "${string}" | grep -oe "[^|]*.*[^|]*")
					# return the folderloaction
					magentoPath=$(echo "${string}" | grep -oe "[${sp};]DocumentRoot${s}${s}*[^;]*" | sed -e "s/^[${sp};]*DocumentRoot['${sp}]*//g" | sed -e "s/['${sp}]*$//g") # | sed -e 's/"*//g' )
				fi 
			fi
		fi
    # if nginx
    elif [ ! -z "${isNginx}" ] ; then
    	 nginxConfDir='/etc/nginx/sites-enabled'
    	 if [ -d "${nginxConfDir}" ] ; then
			nginxConfFile=$( grep --files-with-matches "^${s}*server_name${s}${s}*${url}[${sp};]" ${nginxConfDir}/* )
	   		echo "using this nginx conf file: ${nginxConfFile}"
    		if [ "${#nginxConfFile[@]}" = "1" ] ; then # check if desired no of files
    			if [ ! -z "${nginxConfFile}" ]; then # line needed to check not empty array of length 1
				  string=$( sed -e 's/[#].*$//' < ${nginxConfFile} )
				  # add ; to EOL and put into single line
				  string=$( echo "${string}" | sed -e 's/$/;/g' | sed ':a;N;$!ba;s/\n//g' );
				  # add |'s to allow patern matching of | separeted sections
				  delimter=";${s}*server${s}${s}*{"
				  string=$( echo "${string}" | sed -e "s/${delimter}/|/g" );
				  # return section that has our server info
				  string=$(echo "${string}" | grep -oe "[^|]*[${sp};]server_name${s}${s}*${url}[${sp};][^|]*")
				  # return the folder location
				  magentoPath=$(echo "${string}" | sed -e "s/{[^}]*}//g" | grep -oe "[${sp};]root${s}${s}*[^;]*" | sed -e "s/^[${sp};]*root${s}*//g" | sed -e "s/[${sp}]*$//g" ) # | sed -e 's/"*//g'| sed -e "s/'*//g" )
				else
					numFiles=(${nginxConfDir}/*);
					numFiles=${#numFiles[@]};
					if [ "${numFiles}"="1" ] ; then
				    	nginxConfSingleFile=(${nginxConfDir}/*)
		   	    		echo "trying this nginx config file: ${nginxConfSingleFile[@]}"
				    fi
		        fi
		    fi
    		if [ "${#nginxConfSingleFile[@]}" = "1" ] ; then # check if desired no of files
    			if [ ! -z "${nginxConfSingleFile}" ] ; then # line needed to check not empty array of length 1
		    	    # remove comments
		    	    string=$( sed -e 's/[#].*$//' <  ${nginxConfSingleFile} )
		    	    # find lines setting server name
		    	    hostsSetInFile=$( echo "${string}" | grep "^${s}*server_name${s}" )
		    	    # if file dosnt set a server name then safe to assume its our file
		    	    if [ -z "$hostsSetInFile" ] ; then
		    	    	# add ; to EOL and put into single line
				  		string=$( echo "${string}" | sed -e 's/$/;/g' | sed ':a;N;$!ba;s/\n//g' );
						# add |'s to allow patern matching of | separeted sections
						delimter=";${s}*server${s}${s}*{"
						string=$( echo "${string}" | sed -e "s/${delimter}/|/g" );
						# # return section that has our server info
						# return the folder location
						magentoPath=$(echo "${string}" | sed -e "s/{[^}]*}//g" | grep -oe "[${sp};]root${s}${s}*[^;]*" | sed -e "s/^[${sp};]*root${s}*//g" | sed -e "s/[${sp}]*$//g" )
					fi
    			fi
    		fi
	    fi
    fi
    if [ -z "${magentoPath}" ] ; then
    	echo 'Document root not found';
    	exit;
    else
        echo "magentoPath=${magentoPath}"
    fi
fi

if [ "${siteRootTest}" != "true" ] ; then
    # replace ~ with user folder
    magentoPath="${magentoPath/\~/${userDir}}"
    cd ${magentoPath}

    #### magento db dump ####
    fileRef="${url}-magento"
    date=`date +%Y-%m-%d`;
    fileName="${fileRef}--${date}.sql"
    filePath="${folderPath}/${fileName}"

    # set the truncate table list
    if [ "${truncateRewrites}" = "true" ] ; then
        truncateTablesList='enterprise_url_rewrite_redirect_rewrite enterprise_url_rewrite_redirect_cl \
        enterprise_url_rewrite_redirect enterprise_url_rewrite_product_cl enterprise_url_rewrite_category_cl \
        enterprise_url_rewrite enterprise_catalog_product_rewrite enterprise_catalog_category_rewrite \
        core_url_rewrite @development';
        echo "truncateTableList = ${truncateTablesList}"
    else
        truncateTablesList='@development';
        echo "truncateTableList = ${truncateTablesList}"
    fi

    # if db folder dosnt exist create it
    if [ ! -d "${folderPath}" ] ; then
            mkdir -p "${folderPath}"
    fi

    # empty db folder of tar.gz files
    if [ ! -w "${folderPath}" ] ; then
        echo "${folderPath} is not writable"
        exit
    else
        if ls ${folderPath}/${url}*.tar.gz 1> /dev/null 2>&1; then
            echo "removing old files from ${folderPath}"
            rm ${folderPath}/${url}*.tar.gz
        else
            echo "${folderPath} is empty"
        fi
    fi

    # if n98 not installed, install it
    n98Reply=$(n98-magerun.phar)
    n98Location=""
    if [ -z "${n98Reply}" ] ; then
        n98Location="/tmp/"
        # if ${n98Location}n98-magerun.phar not executable
        if [ ! -x ${n98Location}n98-magerun.phar ] ; then
            echo "attempting to install n98 in /tmp folder"
            wget http://files.magerun.net/n98-magerun-latest.phar -O ${n98Location}n98-magerun.phar &&
            chmod +x ${n98Location}n98-magerun.phar &&
            echo "installed n98 successfully"
        fi
        if [ ! -x ${n98Location}n98-magerun.phar ] ; then
            n98Location="${userDir}/"
            echo "attempting to install n98 in user folder"
            wget http://files.magerun.net/n98-magerun-latest.phar -O ${n98Location}n98-magerun.phar &&
            chmod +x ${n98Location}n98-magerun.phar &&
            echo "installed n98 successfully"
        fi
    fi

    # n98 db dump if dosnt exist
    if [ ! -a "${filePath%.sql}.tar.gz" ] ; then
        if [ ! -e "${filePath}.lock" ] ; then
            touch "${filePath}.lock" &&
            ${n98Location}n98-magerun.phar db:dump --strip="${truncateTablesList}" ${filePath} &&
            tar -czf "${filePath%.sql}.tar.gz" --directory ${folderPath} ${fileName}
            rm -f "${filePath}.lock"
            rm ${filePath}
        fi
    fi

    #### wordpress db dump ####
    # has it got wordpress subsites
    hasWordpress="false"
    if ls ./*/wp-config.php 1> /dev/null 2>&1; then
        echo "wordpress subsite found"
        hasWordpress="true"
    else
        echo "no wordpress subsite found"
    fi
    # dump all wordpress databases
    if [ "${hasWordpress}" = "true" ] ; then
        echo "wordpress=true"   ###--delete me
        
        # create empty wordpress setting file
        wordpressSettingFileName="${url}.wpsetting"
        echo '' > ${folderPath}/${wordpressSettingFileName}
        
        # find all working subsite wordpress installations config files
        wordpressConfigFiles=$(ls -x ./*/wp-config.php)
        
        # for each wordpress install
        for configFile in ${wordpressConfigFiles}; do
            
            wordpressFolder=$( echo "${configFile%/*}" | sed s/^[[:space:]]*[./]*// )

            # get wordpress database access settings
            dbName=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_NAME' | sed -e "s/.*,[[:space:]]*'\(.*\)'.*/\1/" )
            dbUser=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_USER' | sed -e "s/.*,[[:space:]]*'\(.*\)'.*/\1/" )
            dbPass=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_PASSWORD' | sed -e "s/.*,[[:space:]]*'\(.*\)'.*/\1/" )
            dbHost=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'DB_HOST' | sed -e "s/.*,[[:space:]]*'\(.*\)'.*/\1/" )
            tablePrefix=$( sed -e 's/[#].*$//' <  ${configFile}  | grep 'table_prefix' | sed -e "s/.*=[[:space:]]*'\(.*\)'.*/\1/" )

            # make db dump file path
            date=`date +%Y-%m-%d`
            fileName="${url}-${dbName}--${date}.sql"
            filePath="${folderPath}/${fileName}"

            # add wordpress database settings into the wordpress setting file
            echo "[${wordpressFolder}]" >> ${folderPath}/${wordpressSettingFileName}
            echo "fileName=${filePath%.sql}.tar.gz" >> ${folderPath}/${wordpressSettingFileName}
            echo "dbName=${dbName}" >> ${folderPath}/${wordpressSettingFileName}
            echo "tablePrefix=${tablePrefix}" >> ${folderPath}/${wordpressSettingFileName}

            # dump database if not already done
            if [ ! -a "${filePath%.sql}.tar.gz" ] ; then
                if [ ! -e "${filePath}.lock" ] ; then
                    touch "${filePath}.lock" &&
                    mysqldump -h ${dbHost} -u${dbUser} -p${dbPass} ${dbName} > ${filePath} &&
                    tar -czf "${filePath%.sql}.tar.gz" --directory ${folderPath} ${fileName}
                    rm -f "${filePath}.lock" &&
                    rm ${filePath}
                fi
            fi

        done
    fi
fi

unset magentoPath
unset folderPath

echo 'Finished'
if [ -z "${truncateRewrites}" ]; then
	truncateRewrites=true  ######### should this set to yes by default
fi

if [ -z "${magentoPath}" ]; then
	magentoPath='~/public_html'
fi
if [ -z "${folderPath}" ]; then
	folderPath='/tmp/databases'
fi

cd ${magentoPath}

#get site url
sqlQuery="select * from core_config_data where path = 'web/unsecure/base_url' and scope = 'default'"
siteUrl=$(n98-magerun.phar db:query "")
siteUrl=${siteUrl##*\:\/\/} #remove all text before the ://
siteUrl=${siteUrl%\/} #remove trailing /

dbName=$(n98-magerun.phar db:info dbname)
databaseRef="${siteUrl}-dbName"

date=`date +%Y-%m-%d`;
filName="{databaseRef}-${date}.sql"
filePath="${folderPath}/${fileName}"

if [ "${truncateRewrites}"="true" ] ; then
    truncateTablesList = 'core_url_rewrite @development';
else
    truncateTablesList = '@development';
fi

if [ ! -d "${folderPath}" ] ; then
	mkdir --parents ${folderPath}
fi

if [ ! -w "${folderPath}" ] ; then
	echo "${folderPath} is not writable"
	exit
fi

if [ ! -a "${filePath}" ] ; then
	if [ ! -e "${filePath}.lock" ] ; then
		touch "${filePath}.lock" &&
		rm "${folderPath}/${databaseRef}-*.tar.gz"
		/tmp/n98-magerun.phar db:dump --strip="$truncateTablesList" ${filePath} &&
		tar -czf "${filePath}.tar.gz" --directory ${folderPath} $file &&
		rm -f "${filePath}.lock" &&
		rm ${filePath}
	fi
fi

unset magentoPath
unset folderPath
truncateRewrites=true
databaseRef='test'

if [ -z "${magentoPath}" ]; then
	magentoPath=$1
fi

date=`date +%Y-%m-%d`;
folderPath='/tmp/database'
filName="{databaseRef}-${date}.sql"
filePath="${folderPath}/${fileName}"

if [ "${truncateRewrites}"="true" ] ; then
    $truncateTablesList = 'core_url_rewrite @development';
else
    $truncateTablesList = '@development';
fi

if [ ! -d "${folderPath}" ] ; then
	mkdir --parents ${folderPath}
fi

if [ ! -w "$dnam" ] ; then
	echo "${folderPath} is not writable"
	exit
fi

if [ !(-a "${filePath}") ] ; then
	touch "${filePath}.lock" &&
	rm "${folderPath}/${databaseRef}-*.tar.gz"
	cd ${magentoPath}
	/tmp/n98-magerun.phar db:dump --strip="$truncateTablesList" ${filePath} &&
	tar -czf "${filePath}.tar.gz" --directory ${folderPath} $file &&
	rm -f "${filePath}.lock" &&
	rm ${filePath}
fi


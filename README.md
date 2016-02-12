# muliple-external-magento-database-download

##bash
Bash will fetch a magento database from a group of your dev sites automatically removing old ones, so it can be fired nightly by a cron. Also for each site it will detect Wordpress sites directly in folders inside the magento website root (e.g. htdocs/blog)

###Installation
- add all the files in the bash folder onto your database storage server, no files need to go onto the dev server
- add a new server to download list by running addNewSiteToList.sh
- to run full program program run the getAllDatabase.sh, I suggest a cron for this
- the databases will be in compressed files in a databases folder created where you put the bash files

###Removing sites from list
Just remove the site's settings from the sites.ini file

###Limitations
- For automatic fetching document root location nginx sites-enabled files cant have server_name or root stated on the same line as something else
- compressed databases are left in a /tmp/databases folder on the dev servers, but only one of each and this folder is emptied each time the script runs
- the document root may not always be found automatically. If you run the addNewSiteToList.sh script it will inform you of this and ask for a document root.
- requires ssh-copy-id for adding key to server if its not already there

###notes
Outputs like the below from the db dump script is nothing to worry about. Its n98-magerun.phar falling back  to the /tmp/magento/var folder as your magento system is using that instead of the standard of the var folder inside you web document root
```Fallback folder /tmp/magento/var is used in n98-magerun

n98-magerun is using the fallback folder. If there is another folder configured for Magento, this can cause serious problems.
Please refer to https://github.com/netz98/n98-magerun/wiki/File-system-permissions for more information.

Fallback folder /tmp/magento/var is used in n98-magerun

n98-magerun is using the fallback folder. If there is another folder configured for Magento, this can cause serious problems.
Please refer to https://github.com/netz98/n98-magerun/wiki/File-system-permissions for more information.```

##php
Php scripts to fetch a magento database from a group of your dev sites automatically removing old ones, so it can be fired nightly by a cron.

###Installation

####for each dev site
- Add latestdb.php into the web root
- Replace the ip 123.12.12.123 with the ip of the dev server to give it access.
- uncomment and adjust the time in secounds the script timeout `//set_time_limit('3600')` if required or testing

####on the database server
- add dbDownloader.php to the server, and is best not made accessible by the web
- Replace the ip 123.12.12.123 with your ip for testing
- Change $urlList to a list of your dev site urls
- Check the web server can write to the databases folder when it is created. Dont change it to 777 if you can help it.
- test it works by firingthe dbDownloader.php via command line 
    `php path/to/file/dbDownloader.php`
  If this fails check your dev sites are creating the databases in the /tmp folder and try running the latestdb.php script manually on the dev site, to see where it fails.
- setup the cron to run the command you fired earlier
    `php path/to/file/dbDownloader.php`

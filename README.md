# database-dump-php-cron
Php scripts to fetch a magento database from a group of your dev sites automatically removing old ones, so it can be fired nightly by a cron.

##Installation

#####for each dev site
- Add latestdb.php into the web root
- Replace the ip 123.12.12.123 with the ip of the dev server to give it access.
- uncomment and adjust the time in secounds the script timeout `//set_time_limit('3600')` if required or testing

#####on the database server
- add dbDownloader.php to the server, and is best not made accessible by the web
- Replace the ip 123.12.12.123 with your ip for testing
- Change $urlList to a list of your dev site urls
- Check the web server can write to the databases folder when it is created. Dont change it to 777 if you can help it.
- test it works by firingthe dbDownloader.php via command line 
    `php path/to/file/dbDownloader.php`
  If this fails check your dev sites are creating the databases in the /tmp folder and try running the latestdb.php script manually on the dev site, to see where it fails.
- setup the cron to run the command you fired earlier
    `php path/to/file/dbDownloader.php`

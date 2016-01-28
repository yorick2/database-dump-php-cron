# database-dump-php-cron

##bash
Bash will fetch a magento database from a group of your dev sites automatically removing old ones, so it can be fired nightly by a cron. Also for each site it will detect Wordpress sites directly in folders inside the magento website root (e.g. htdocs/blog)

###Installation
- add all the files in the bash folder onto your database storage server, no files need to go onto the dev server
- Copy example.ini to sites.ini
- change the site listing to your sites
- comment out the docRoot line with a ; or # at the start 
- test if the program can automatically find the website root folder by running checkLastSiteRoot.sh and it will return the path to the root folder of the last site in the sites.ini if its successful.
- if it is unsuccessful add the line docRoot to your site listing the sites.ini, which can include a ~
- to run program run the getAllDatabase.sh
- the databases will be in compressed files in a databases folder created where you put the bash files

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

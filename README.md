# muliple-external-magento-database-download

## bash
Bash will fetch a Magento 1 or Magento 2 or Wordpress database from a group of your dev sites automatically removing old ones, so it can be fired nightly by a cron. Also for each site it will detect Wordpress sites directly in folders inside the magento website root (e.g. htdocs/blog). 

### Installation
- add all the files in the bash folder onto your database storage server, no files need to go onto the dev server
- add your ssh key onto the dev server. I suggest installing and using ssh-copy id on your database storage server for this.
- add a new server to download list by running the addNewSiteToList.sh file
- to run full program run the getAllDatabase.sh file, I suggest a nightly cron for this.
- the databases will be in compressed files (tar.gz) in a databases folder created where you put the bash files
- if you want a site to dump a database without the rewrites table add this line in the sites.ini file ```truncateRewrites = true```

### adding in a new site into the download list
- add your ssh key onto the dev server. I suggest installing and using ssh-copy id on your database storage server for this. If its installed run `ssh-copy-id user@example.com` where user is the username and provide the user's password. It will add the ssh key if able.
- check you can ssh from the database storage server to the dev server without giving a password. If it asks for a password its not able to connect with the ssh key. `ssh user@example.com`
- dont forget to exit the dev server, to return to the database storage server
- run the addNewSiteToList.sh file. The easiest way is to go to the folder and type `./addNewSiteToList.sh`. This should be pretty obvious and will update the site.ini file with new details once the required details are filled in.
- run a test download using the checkLastSiteRoot.sh script, if you didnt do so while running the addNewSiteToList.sh script.


### Removing sites from list
Just remove the site's settings from the sites.ini file, unfortunately currently commenting out dosnt work but may be added in the future.

### Limitations
- For automatic fetching document root location nginx sites-enabled files cant have server_name or root stated on the same line as something else
- compressed databases are left in a /tmp/databases folder on the dev servers, but only one of each and this folder is emptied each time the script runs
- the document root may not always be found automatically. If you run the addNewSiteToList.sh script it will inform you of this and ask for a document root.
- requires ssh-copy-id for adding key to server if its not already there
- Magento 2 databases cant use the truncate rewrites option as database structure may have changed 


### Test a single site
getAllDatabase.sh <<site name defined in sites.ini>>
e.g. getAllDatabase.sh example-site

note: the site name is found in the sites.ini file between the [] above the site info

### Notes
Outputs like the below from the db dump script is nothing to worry about. Its n98-magerun.phar falling back to the /tmp/magento/var folder as your magento system and is using that instead of the standard of the var folder inside your web document root.

``` Fallback folder /tmp/magento/var is used in n98-magerun .... ```

### Trouble shooting
The most common issue is that the sh files need to have excute permissions for the user trying to run them or permission issues writing to the database folder.

## php
Php scripts to fetch a magento database from a group of your dev sites automatically removing old ones, so it can be fired nightly by a cron.

### Installation

#### for each dev site
- Add latestdb.php into the web root
- Replace the ip 123.12.12.123 with the ip of the dev server to give it access.
- uncomment and adjust the time in secounds the script timeout `//set_time_limit('3600')` if required or testing

#### On the database server
- add dbDownloader.php to the server, and is best not made accessible by the web
- Replace the ip 123.12.12.123 with your ip for testing
- Change $urlList to a list of your dev site urls
- Check the web server can write to the databases folder when it is created. Dont change it to 777 if you can help it.
- test it works by firingthe dbDownloader.php via command line 
    `php path/to/file/dbDownloader.php`
  If this fails check your dev sites are creating the databases in the /tmp folder and try running the latestdb.php script manually on the dev site, to see where it fails.
- setup the cron to run the command you fired earlier
    `php path/to/file/dbDownloader.php`

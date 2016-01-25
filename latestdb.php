<?php

if(!in_array($_SERVER['REMOTE_ADDR'], array('192.168.0.1','123.12.12.123'))){
        http_response_code(404);
        exit();
}

$truncateRewrites = true;
//set_time_limit('3600');

$xml = simplexml_load_string(file_get_contents('./app/etc/local.xml'), "SimpleXMLElement", LIBXML_NOCDATA);
$json = json_encode($xml);
$array = json_decode($json, true);

$connection = $array['global']['resources']['default_setup']['connection'];
// db config
$dbname = $connection['dbname'];

$file = $dbname . '_' . date('dmY') . '.sql';
$tmpfname = '/tmp/'. $file;


if ( !file_exists($tmpfname . '.lock') ) {

    if(!file_exists('/tmp/n98-magerun.phar')) {
        exec('wget http://files.magerun.net/n98-magerun-latest.phar -O /tmp/n98-magerun.phar');
    }
    if(file_exists($tmpfname)) {
        unlink($tmpfname);
    }
    if(file_exists($tmpfname.'.tar.gz')) {
        unlink($tmpfname.'.tar.gz');
    }

    exec('chmod +x /tmp/n98-magerun.phar');
 
    if($truncateRewrites){
        $truncateTablesList = 'core_url_rewrite';
    }else{
        $truncateTablesList = '';
    }
    
    $command = '('
            . ' touch ' . $tmpfname . '.lock'
            . ' && /tmp/n98-magerun.phar db:dump --strip="'.$truncateTablesList.' @development" '.$tmpfname
            . ' && tar -czf '.$tmpfname.'.tar.gz --directory /tmp '.$file
            . ' && rm -f ' . $tmpfname . '.lock'
            . ' && rm ' . $tmpfname
            . '  ) &';

    exec($command);
}

for($i=0 ; $i<30 ; $i++){
    if ( !file_exists($tmpfname . '.lock') ) {
        header('Content-Description: File Transfer');
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . basename($file.'.tar.gz') . '"');
        header('Expires: 0');
        header('Cache-Control: must-revalidate');
        header('Pragma: public');
        header('Content-Length: ' . filesize($tmpfname.'.tar.gz'));
        readfile($tmpfname.'.tar.gz');
        exit;
    }
    sleep('10');
}
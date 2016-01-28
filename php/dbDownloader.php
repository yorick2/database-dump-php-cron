<?php

if(!in_array($_SERVER['REMOTE_ADDR'], array('192.168.0.1','127.0.0.1','12.123.12.123'))){
        http_response_code(404);
        exit();
}

error_reporting(~0);
ini_set('display_errors', 1);
set_time_limit(0);

$dbFolder = 'databases';
if (!file_exists($dbFolder)) {
    mkdir($dbFolder, 0777, true);
}

// array of site urls
$urlList = [
    'http://test.com/',
    'example.co.uk'    
];

for ($i=0; $i < sizeof($urlList); $i++){
    
    $url = $urlList[$i];
    if( strpos($url,'http://') !== false ){
        $url = str_replace('http://', '', $url);
    }
    if( substr($url, -1) === '/' ){
        $url = rtrim($url,'/');
    }
    
    if ( is_writable($dbFolder) ){
        set_time_limit(0);
        $fp = fopen ($dbFolder.'/'.$url . '_' . date('dmY') . '.tar.gz','w+');
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
        curl_setopt($ch, CURLOPT_HEADER, 0);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
        curl_setopt($ch, CURLOPT_URL,'http://'.$url.'/latestdb.php');
        curl_setopt($ch, CURLOPT_FILE, $fp);
        $result['content']=curl_exec($ch);
        $result['info']=curl_getinfo($ch);
        var_dump($result);
        
        $cond = ( $result['info']['download_content_length'] > 500 );
        $cond2 = ( $result['info']['size_download'] === $result['info']['download_content_length'] );
        $cond3 = ( $result['content'] === true );
        if( $cond && $cond2 && $cond3){
            $fileToRemove = $dbFolder.'/'.$url . '_' . date('dmY',strtotime("-2 days")) . '.tar.gz';
            if( file_exists($fileToRemove) ){
                    unlink($fileToRemove);
            }
            $fileToRemove = $dbFolder.'/'.$url . '_' . date('dmY',strtotime("-3 days")) . '.tar.gz';
            if( file_exists($fileToRemove) ){
                    unlink($fileToRemove);
            }
            
        }
    }else{
        error_log($dbFolder.' folder is not writable');
    }
}

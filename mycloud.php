<?php 

error_reporting(E_ALL);
set_time_limit(0);
ob_implicit_flush();

$listener = WebSocket("192.168.18.129",12345);
$sockets  = array($listener);
$users    = array();
$debug    = true;

while(true)
{
   $changed = $sockets;
   socket_select($changed,$write=NULL,$except=NULL,NULL);
   foreach($changed as $socket)
   {
     if($socket==$listener)
     {
        $client=socket_accept($listener);
        if($client<0){ console("socket_accept() failed"); continue; }
        else{ connect($client); }
     }
     else
     {
        $bytes = @socket_recv($socket,$buffer,2048,0);
        if($bytes==0){ disconnect($socket); }
        else
        {
           $user = getuserbysocket($socket);
           if(!$user->handshake){ dohandshake($user,$buffer); }
           else{ process($user,$buffer); }
        }
     }
   }
}

require_once("db.php");

function process($user,$msg)
{
   global $users;
   
   $action = hybi10Decode($msg);//unwrap($msg);
   $action = $action['payload'];
    
   say("Recv: ".$action);

   $prefix = substr($action, 0, strpos($action, ":"));
   $suffix = substr($action, strpos($action, ":")+1);

   $arrayResult = null;
   $opcode = "";
   $filename = "";
   $uid1 = "";
   $uid2 = "";
   $ip = "";
   
   switch($prefix)
   {
       case "uid:"
       $user->id = intval($suffxi);
       $db = open_database();
       $userinfo = get_user();
       close_database($db);

       foreach($users as $u)
       {
           send($u->socket, $userinfo);            
       }
       break;
 
       case "scene:"
       break;

       case "control":
       $arrayResult = explode(";", $suffix);
       $opcode = $arrayResult[0];
       $filename = $arrayResult[1];
       $uid1 = $arrayResult[2];
       $uid2 = $arrayResult[3];
       foreach($users as $u)
       { // !== Just for testing
          // if($u->id !== intval($uid2) ||
            //  $u->id !== intval($uid1))
           {
              send($u->socket, "control:".$opcode.";".$filename.";".$uid1);
              //break;
           }
       } 
      
       break;
    
       case "inter-control":
       $arrayResult = explode(";", $suffix);
       $opcode = $arrayResult[0];
       $filename = $arrayResult[1];
       $uid1 = $arrayResult[2];
       $uid2 = $arrayResult[3];
       $ip = $arrayResult[4];
       
       break;
    
       case "inter-shared"  : 
       $arrayResult = explode(";", $suffix);
       $opcode = $arrayResult[0];
       $filename = $arrayResult[1];
       $uid1 = $arrayResult[2];
       $uid2 = $arrayResult[3];
       $ip = $arrayResult[4];

       break;
    
       default: 
       console("Invalid message received!");	
 
       break;
    }
}

function send($client,$msg)
{
   say("Send: " . $msg);
  
   $msg = hybi10Encode($msg);//wrap($msg);
   socket_write($client,$msg,strlen($msg));
}

function WebSocket($address,$port)
{
   $listener=socket_create(AF_INET, SOCK_STREAM, SOL_TCP)     or die("socket_create() failed");
   socket_set_option($listener, SOL_SOCKET, SO_REUSEADDR, 1)  or die("socket_option() failed");
   socket_bind($listener, $address, $port)                    or die("socket_bind() failed");
   socket_listen($listener,20)                                or die("socket_listen() failed");
   echo "Server Started : ".date('Y-m-d H:i:s')."\n";
   echo "Listener socket  : ".$listener."\n";
   echo "Listening on   : ".$address." port ".$port."\n\n";
   return $listener;
}

function connect($socket)
{
   global $sockets,$users;
   
   $user = new User();
   //$user->id = uniqid();
   $user->socket = $socket;
   
   array_push($users,$user);
   array_push($sockets,$socket);
   
   console($socket." CONNECTED!");
}

function disconnect($socket)
{
   global $sockets,$users;
   $found=null;
   $n=count($users);
   
   for($i=0;$i<$n;$i++)
   {
     if($users[$i]->socket==$socket){ $found=$i; break; }
   }
  
   if(!is_null($found)){ array_splice($users,$found,1); }
   
   $index = array_search($socket,$sockets);
   socket_close($socket);
  
   console($socket." DISCONNECTED!");
  
   if($index>=0){ array_splice($sockets,$index,1); }
}

function dohandshake($user,$buffer)
{
   console("\nRequesting handshake...");
   console($buffer);
  
   list($resource,$host,$origin,$strkey1,$Ext1,$data) = getheaders($buffer);
  
   console("Handshaking...");

   $hash_data = sha1($strkey1."258EAFA5-E914-47DA-95CA-C5AB0DC85B11", true);
   $upgrade   = "HTTP/1.1 101 Switching Protocols\r\n" .
                "Upgrade: websocket\r\n" .
                "Connection: Upgrade\r\n" .
                "Sec-WebSocket-Origin: " . $origin . "\r\n" .
                "Sec-WebSocket-Location: ws://" . $host . $resource . "\r\n" .
                "Sec-WebSocket-Accept: " . base64_encode($hash_data) . 
                "\r\n\r\n";
 
  console($upgrade);
    
  socket_write($user->socket,$upgrade,strlen($upgrade));
  $user->handshake=true;
   
  console("Done handshaking...");
  
  return true;
}

function getheaders($req)
{
   $r=$h=$o=null;
   if(preg_match("/GET (.*) HTTP/"   ,$req,$match)){ $r=$match[1]; }
   if(preg_match("/Host: (.*)\r\n/"  ,$req,$match)){ $h=$match[1]; }
   if(preg_match("/Origin: (.*)\r\n/",$req,$match)){ $o=$match[1]; }
   if(preg_match("/Sec-WebSocket-Key: (.*)\r\n/",$req,$match)){ $key1=$match[1]; } 
   if(preg_match("/Sec-WebSocket-Extensions: (.*)\r\n/",$req,$match)){ $Ext1=$match[1]; } 
   if(preg_match("/\r\n(.*?)\$/",$req,$match)){ $data=$match[1]; }
  
   return array($r,$h,$o,$key1,$Ext1,$data);
}

function getuserbysocket($socket)
{
   global $users;
  
   $found=null;
   foreach($users as $user){
     if($user->socket==$socket){ $found=$user; break; }
   }
  
  return $found;
}

function ord_hex($data) 
{  
   $msg = "";  
   $l = strlen($data);  
  
   for ($i= 0; $i< $l; $i++) {  
        $msg .= dechex(ord($data{$i}));  
   }  
  
   return $msg;  
}  

function say($msg=""){ echo $msg."\n"; }

function wrap($msg="")
{
    return chr(0).utf8_encode($msg).chr(255);
}

function hybi10Encode($payload, $type = 'text', $masked = false) 
{
        $frameHead = array();
        $frame = '';
        $payloadLength = strlen($payload);

        switch ($type) {
            case 'text':
                // first byte indicates FIN, Text-Frame (10000001):
                $frameHead[0] = 129;
                break;

            case 'close':
                // first byte indicates FIN, Close Frame(10001000):
                $frameHead[0] = 136;
                break;

            case 'ping':
                // first byte indicates FIN, Ping frame (10001001):
                $frameHead[0] = 137;
                break;

            case 'pong':
                // first byte indicates FIN, Pong frame (10001010):
                $frameHead[0] = 138;
                break;
        }

        // set mask and payload length (using 1, 3 or 9 bytes)
        if ($payloadLength > 65535) {
            $payloadLengthBin = str_split(sprintf('%064b', $payloadLength), 8);
            $frameHead[1] = ($masked === true) ? 255 : 127;
            for ($i = 0; $i < 8; $i++) {
                $frameHead[$i + 2] = bindec($payloadLengthBin[$i]);
            }

            // most significant bit MUST be 0 (close connection if frame too big)
            if ($frameHead[2] > 127) {
                $this->close(1004);
                return false;
            }
        } elseif ($payloadLength > 125) {
            $payloadLengthBin = str_split(sprintf('%016b', $payloadLength), 8);
            $frameHead[1] = ($masked === true) ? 254 : 126;
            $frameHead[2] = bindec($payloadLengthBin[0]);
            $frameHead[3] = bindec($payloadLengthBin[1]);
        } else {
            $frameHead[1] = ($masked === true) ? $payloadLength + 128 : $payloadLength;
        }

        // convert frame-head to string:
        foreach (array_keys($frameHead) as $i) {
            $frameHead[$i] = chr($frameHead[$i]);
        }

        if ($masked === true) {
            // generate a random mask:
            $mask = array();
            for ($i = 0; $i < 4; $i++) {
                $mask[$i] = chr(rand(0, 255));
            }

            console("\nServer should not send masked frame!\n");

            $frameHead = array_merge($frameHead, $mask);
        }
        $frame = implode('', $frameHead);
        // append payload to frame:
        for ($i = 0; $i < $payloadLength; $i++) {
            $frame .= ($masked === true) ? $payload[$i] ^ $mask[$i % 4] : $payload[$i];
        }

        return $frame;
}

function hybi10Decode($data)
{
	$payloadLength = '';
	$mask = '';
	$unmaskedPayload = '';
	$decodedData = array();

	// estimate frame type:
	$firstByteBinary = sprintf('%08b', ord($data[0]));
	$secondByteBinary = sprintf('%08b', ord($data[1]));
	$opcode = bindec(substr($firstByteBinary, 4, 4));
	$isMasked = ($secondByteBinary[0] == '1') ? true : false;
	$payloadLength = ord($data[1]) & 127;
	
	// close connection if unmasked frame is received:
	if($isMasked === false)
	{
	    $this->close(1002);
	}
	
	switch($opcode)
	{
	// text frame:
	 case 1:
	   $decodedData['type'] = 'text';
	   break;
	
	 case 2:
	   $decodedData['type'] = 'binary';
	   break;
	
	// connection close frame:
	case 8:
	   $decodedData['type'] = 'close';
	   break;
	
        // ping frame:
        case 9:
	   $decodedData['type'] = 'ping';
	   break;
	 
        // pong frame:
        case 10:
	   $decodedData['type'] = 'pong';
	   break;
	
        default:
	 // Close connection on unknown opcode:
	   $this->close(1003);
	   break;
       }

       if($payloadLength === 126)
       {
	   $mask = substr($data, 4, 4);
	   $payloadOffset = 8;
	   $dataLength = bindec(sprintf('%08b', ord($data[2])) . sprintf('%08b', ord($data[3]))) + $payloadOffset;
       }
       elseif($payloadLength === 127)
       {
	   $mask = substr($data, 10, 4);
	   $payloadOffset = 14;
	   $tmp = '';
	   for($i = 0; $i < 8; $i++)
	   {
	       $tmp .= sprintf('%08b', ord($data[$i+2]));
	   }
	   $dataLength = bindec($tmp) + $payloadOffset;
	   unset($tmp);
       }
       else
       {
	  $mask = substr($data, 2, 4);
	  $payloadOffset = 6;
	  $dataLength = $payloadLength + $payloadOffset;
       }
	
	// * We have to check for large frames here. socket_recv cuts at 1024 bytes
	// * so if websocket-frame is > 1024 bytes we have to wait until whole
	// * data is transferd.
	// */
       if(strlen($data) < $dataLength)
       {
	   return false;
       }
       if($isMasked === true)
       {
	   for($i = $payloadOffset; $i < $dataLength; $i++)
	   {
	       $j = $i - $payloadOffset;
	       if(isset($data[$i]))
	       {
		   $unmaskedPayload .= $data[$i] ^ $mask[$j % 4];
   	       }
	   }
       
           $decodedData['payload'] = $unmaskedPayload;
       }
       else
       {
	   $payloadOffset = $payloadOffset - 4;
	   $decodedData['payload'] = substr($data, $payloadOffset);
       }

       return $decodedData;
}

function  unwrap($msg="")
{
    // return substr($msg,5,strlen($msg)-6);
    $mask = array();  
    $data = "";  
    $msg = unpack("H*",$msg);  
      
    $head = substr($msg[1],0,2);  
      
    if (hexdec($head{1}) === 8) {  
        $data = false;  
    } else if (hexdec($head{1}) === 1) {  
        $mask[] = hexdec(substr($msg[1],4,2));  
        $mask[] = hexdec(substr($msg[1],6,2));  
        $mask[] = hexdec(substr($msg[1],8,2));  
        $mask[] = hexdec(substr($msg[1],10,2));  
      
        $s = 12;  
        $e = strlen($msg[1])-2;  
        $n = 0;  
        for ($i= $s; $i<= $e; $i+= 2) {  
            $data .= chr($mask[$n%4]^hexdec(substr($msg[1],$i,2)));  
            $n++;  
        }  
    }  
      
    return $data;  
 }

function console($msg=""){ global $debug; if($debug){ echo $msg."\n"; } }

class User
{
  var $id;
  var $socket;
  var $handshake;
}

?>

<?php

/*
if ($handle = opendir('/path/to/files'))
{       
   echo "Directory handle: $handle\n";
  
   echo "Entries:\n";

   while (false !== ($entry = readdir($handle)))
   {
       echo "$entry\n";
   }

   closedir($handle);
}

$printer = "\\\\Pserver.php.net\\printername");
if($ph = printer_open($printer))
{
   // Get file contents
   $fh = fopen("filename.ext", "rb");
   $content = fread($fh, filesize("filename.ext"));
   fclose($fh);
       
   // Set print mode to RAW and send PDF to printer
   printer_set_option($ph, PRINTER_MODE, "RAW");
   printer_write($ph, $content);
   printer_close($ph);
}
else "Couldn't connect...";
*/
#

function getIp() 
{
    $ip = $_SERVER['REMOTE_ADDR'];

    if (!empty($_SERVER['HTTP_CLIENT_IP'])) 
    {
        $ip = $_SERVER['HTTP_CLIENT_IP'];

    } 
    elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR']))
    {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
    }

    return $ip;
}

?>


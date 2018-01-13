<?php
   
   require_once("db.php");
    
   session_start();
   
   $user_name = $_POST["username"];
   $password = $_POST["password"];
   
   if($user_name == "")
   {
       exit("No user name!");	   
   }
   else if($password == "")
   {
       exit("No password!");
   }
   else if($password != "123")
   {
       exit("Incorrect password!");
   }
   else
   {
       $_SESSION['user'] = $user_name;

       $db = open_database("mycloud");
       add_user(3,1,1,$user_name);
       $userId = mysql_insert_id($db);
       close_database($db);

       echo $userId;
   }
?>

<html>
<head>
</head>

<body>
	    <p><h2>192.168.18.129---MyCloud<h2></p>
            <hr>
	    <br><br><br>
	    <div align="center">
		    <h1>Welcome Jacky&Claire</h1>
	    </div>
<br>
<div align="center">
  <table>
    <tr>
      <td style="padding-right:50px;">
        <div align="center"><a href="datanetwork.php" target="content"><img src="cloud.png"></a></div>
      </td>
      <td style="padding-left:50px;">
        <div align="center>"<a href="datanetwork.php" target="content"><img src="cloud.png"></a></div>
      </td>
    </tr>
    <tr>
      <td>
        <div align="center"><label><h1>Network</h1></label></div> 
      </td>
      <td>
        <div align="center"><label><h1>Scene</h1></label></div>
      </td>
    </tr>
  </table>
</div>

</body>
</html>


<?php

function open_database($database)
{
    $db = mysql_connect("localhost:3306", "root", "123456");
    mysql_select_db($database);

    return $db;
}

function close_database($db)
{
    mysql_close($db);
}

function get_users()
{
    $sel_sql = "select * from user";

    $result = mysql_query($sel_sql);

    $str = "";

    while($row = mysql_fetch_array($result))
    {
       $str = $str.$row["id"].":".$row["ring"].":".$row["type"].":".$row["subtype"].":".$row["name"].";";
    }

    return $str;
}

function get_scenes()
{
    $sel_sql = "select * from scene";

    $result = mysql_query($sel_sql);

    $str = "";

    while($row = mysql_fetch_array($result))
    {
       $str = $str.$row["type"].":".$row["uid1"].":".$row["uid2"].";";
    }

    return $str;
}

function get_scene_type()
{
    $sel_sql = "select * from scenetype";

    $result = mysql_query($sel_sql);

    $str = "";

    while($row = mysql_fetch_array($result))
    {
       $str = $str.$row["id"].":".$row["name"].";";
    }

    return $str;
}

function add_user($ring, $type, $subtype, $name)
{
    $insert_sql = "insert into user(ring, type, subtype, name)
	           values($ring, $type, $subtype, '$name')";
    mysql_query($insert_sql);
}

function del_user($uid)
{
    $del_sql = "delete from user where id = ".$uid;
    mysql_query($del_sql);
}

function add_scene($type, $uid1, $uid2)
{
    $insert_sql = "insert into scene(type, uid1, uid2) values($type, $uid1, $uid2)";
    mysql_query($insert_sql);
}

function del_scene($type, $uid1, $uid2)
{
    $del_sql = "delete from scene where type=".$type." and uid1=".$uid1. " and uid2=".$uid2;
    mysql_query($del_sql);
}

/*
$db = open_database("mycloud");

$users = get_users();
echo $users."\n";
$scenes = get_scenes();
echo $scenes."\n";
$scenetype = get_scene_type();
echo $scenetype."\n";

close_database($db);
 */
?>

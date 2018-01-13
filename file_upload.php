<?php

function receive()
{
    $fileReader = fopen('php://input', "r");
    $fileWriter = fopen($_SERVER['HTTP_X_USER_ID']."/".$_SERVER['HTTP_X_FILE_NAME'], "w+");

    while(true) {
        $buffer = fgets($fileReader, 4096);
        if (strlen($buffer) == 0) {
            fclose($fileReader);
            fclose($fileWriter);
            return true;
        }

        fwrite($fileWriter, $buffer);
    }

    return false;
}

receive();

?> 

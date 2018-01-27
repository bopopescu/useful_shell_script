#!/bin/bash

#9002, 9003: WebSocketServer
#4567: ControllerServer
#5678: WeatherServer
#7890: SControllerServer
#8888: installer
portsExpected=(9002 9003 4567 5678 7890 8888)


while true
do

    listenAddr=`netstat -tlpn|awk 'NR>2{print $4}'`

    for((i=0;i<6;++i))
    do
      portExpected=`echo $((portsExpected[$i]))`
      bUP=0
     
      for port in $listenAddr
      do
	  port=${port##*:}
	  if [ $port -eq $portExpected ]
	  then
	      echo "Port: "$port", UP!"
	      bUP=1
	      break
	  fi
      done

      if [ $bUP -eq 0 ] # Service in DOWN state
      then
	  echo "Port: "$portExpected", DOWN!"

	  if [ $i -eq 0 ] || [ $i -eq 1 ] # WebSocketServer 
	  then
	      killall WebSocketServer
	      sleep 5m
              cd /root/WebSocket
	      nohup ./WebSocketServer >> nohup.out 2>&1 &
              cd -
	      echo "Bring WebSocketServer up!"
     
	  elif [ $i -eq 2 ] # ControllerServer
	  then
              cd /root/PCController
	      nohup ./ControllerServer >> nohup.out 2>&1 &
              cd -
	      echo "Bring ControllerServer up!"

	  elif [ $i -eq 3 ] # WeatherServer
	  then 
              cd /root/Weather
	      nohup ./WeatherServer >> nohup.out 2>&1 &
              cd -
	      echo "Bring WeatherServer up!"
	  
	  elif [ $i -eq 4 ] # SControllerServer
	  then
              cd /root/SmallController
	      nohup ./SControllerServer >> nohup.out 2>&1 &
              cd -
	      echo "Bring SControllerServer up!"

	  elif [ $i -eq 5 ] # installer
	  then
              cd /root/Installer
	      nohup ./installer >> nohup.out 2>&1 &
              cd -
	      echo "Bring installer up!"
	  fi
      fi

    done

    sleep 1m

done

exit 0


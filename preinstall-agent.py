import sys
import os
import time
from subprocess import Popen,PIPE
import smtplib
import time
import xmlrpclib
import smtplib
import socket
import base64

def get_mac():
      macCmd = 'ifconfig|awk \'NR==1{print $5;}\''
      macProcess = Popen(macCmd, shell=True, stdout=PIPE)
      macProcess.wait()
      if macProcess.returncode != 0:
	 return ''
      for each in macProcess.stdout:
	return each

def get_ip():
      ipCmd = 'ifconfig|awk \'NR==2{split($2, c, ":");print c[2];}\''
      ipProcess = Popen(ipCmd, shell=True, stdout=PIPE)
      ipProcess.wait()
      if ipProcess.returncode != 0:
	   return ''
      for each in ipProcess.stdout:
	  return each

server_proxy = xmlrpclib.ServerProxy('http://10.1.1.101:5555', allow_none=True)

print 'Create server proxy ok\n'

server_role = sys.argv[1]

logs={}

logs['text']=base64.b64encode('newinstall')
server_proxy.install_update(server_role, logs)

logs['text']=base64.b64encode('Start PXE installation\n')
server_proxy.install_update(server_role, logs)

logs['text']=base64.b64encode('Formatting file system, this will take several minutes, please wait.....\n\n')
server_proxy.install_update(server_role, logs)

logfile1='/mnt/sysimage/root/install.log'
logfile2='/mnt/sysimage/root/install.log.syslog'
logfile3='/mnt/sysimage/root/post-install.log'

file1Found=False
file2Found=False
file3Found=False

while 1:

   time.sleep(5)
   
   if file1Found:
      pass
   else:
      try:
         f1SizeOld=os.stat(logfile1).st_size
         file1Found=True
         incSize1=f1SizeOld
         position1=0
      except Exception, e:
         pass     
   
   if file2Found:
      pass
   else:
      try:
         f2SizeOld=os.stat(logfile2).st_size
         file2Found=True
         incSize2=f2SizeOld
         position2=0
      except Exception, e:
         pass

   if file3Found:
      pass
   else:
      try:
         f3SizeOld=os.stat(logfile3).st_size
         file3Found=True
         incSize3=f3SizeOld
         position3=0
      except Exception, e:
         pass

   if file1Found:
       # More log generated in /mnt/sysimage/root/install.log
       if incSize1 > 0:
	  
	  try:
	     f=open(logfile1, 'rb')
	  except Exception, e:
             logs['text'] = base64.b64encode(e[1] + ': ' + logfile1)
	     server_proxy.install_update(server_role, logs)
	     sys.exit()
	     
	  f.seek(position1, 0)
	  logs['text'] = f.read(incSize1)
	  position1 += len(logs['text'])
	  f.close()
          logs['text'] = base64.b64encode(logs['text']) 
	  server_proxy.install_update(server_role, logs)
       
       f1SizeNew=os.stat(logfile1).st_size
       incSize1=f1SizeNew-f1SizeOld
       f1SizeOld=f1SizeNew

   if file2Found:
       # More log generated in /mnt/sysimage/root/install.log.syslog
       if incSize2 > 0:
	  
	  try:
	     f=open(logfile2, 'rb')
	  except Exception, e:
             logs['text'] = base64.b64encode(e[1] + ': ' + logfile2)
	     server_proxy.install_update(server_role, logs)
	     sys.exit()
	     
	  f.seek(position2, 0)
	  logs['text'] = f.read(incSize2)
	  position2 += len(logs['text'])
	  f.close()
          logs['text'] = base64.b64encode(logs['text']) 
	  server_proxy.install_update(server_role, logs)
       
       f2SizeNew=os.stat(logfile2).st_size
       incSize2=f2SizeNew-f2SizeOld
       f2SizeOld=f2SizeNew

   if file3Found:
       # More log generated in /mnt/sysimage/root/post-install.log
       if incSize3 > 0:
	  
	  try:
	     f=open(logfile3, 'rb')
	  except Exception, e:
             logs['text'] = base64.b64encode(e[1] + ': ' + logfile3)
	     server_proxy.install_update(server_role, logs)
	     sys.exit()
	     
	  f.seek(position3, 0)
	  logs['text'] = f.read(incSize3)
	  position3 += len(logs['text'])
	  f.close()
          logs['text'] = base64.b64encode(logs['text']) 
	  server_proxy.install_update(server_role, logs)
       
       f3SizeNew=os.stat(logfile3).st_size
       incSize3=f3SizeNew-f3SizeOld
       f3SizeOld=f3SizeNew

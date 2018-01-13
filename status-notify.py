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

try:
  cf_server_ip = sys.argv[1]
except Exception, e:
  print e
  sys.exit()

server_proxy = xmlrpclib.ServerProxy('http://' + cf_server_ip + ':8080/cloudfactory', allow_none=True)

device_mac = sys.argv[2]

server_proxy.statusNotify(device_mac, base64.b64encode('installed'))

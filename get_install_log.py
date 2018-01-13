import sys
import os
import smtplib
import xmlrpclib
import smtplib
import socket
import base64

server_role=sys.argv[1]

try:
    cf_server = xmlrpclib.ServerProxy("http://10.1.1.101:5555", allow_none=True)
    logs=cf_server.getInstallLog(server_role)
    logs=base64.b64decode(logs)
    print logs

except Exception, e:
   print e
   print "Port:5555 on Server is not up yet, try again later"





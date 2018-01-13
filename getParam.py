#!/bin/python

import xmlrpclib
import sys

s = xmlrpclib.ServerProxy('http://192.168.10.100:8080/cloudfactory')
result = s.getParam({"macaddress":sys.argv[1],"cluster_id":sys.argv[2]})
param = sys.argv[3]

try:
    count = int(sys.argv[4])
except:
    count = 0

#rets =  result["return"]
rets =  result

try:
  for ret in rets:
    for r in ret:
      if count:
        a,b,c,d = r["%s"%param].split(".")
      if count == 1:
        print a
      elif count == 2:
        print "%s.%s." % (a,b)
      elif count == 3:
        print "%s.%s.%s." % (a,b,c)
      elif count == 4:
        print "%s.%s.%s.%s" % (a,b,c,d)
      elif count == 5:
        print "%s" %(d)
      elif count == 6:
        print "%s" %(c)
      elif count == 7:
        print "%s" %(b)
      else:
        print r["%s"%param]
except:
  pass

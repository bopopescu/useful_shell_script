import sys
import os
from threading import Thread
from SimpleXMLRPCServer import SimpleXMLRPCServer
from SimpleXMLRPCServer import SimpleXMLRPCRequestHandler
import smtplib
import xmlrpclib
import datetime

SQLITE_THREADSAFE=1

# Restrict to a particular path.
class RequestHandler(SimpleXMLRPCRequestHandler):
      rpc_paths = ('/RPC2',)
      
# Kick Start Manager
class KSMgr:
      def __init__(self):
          try:
             self.config = ConfigParser.ConfigParser()
             self.config.read('/usr/src/Manager/KS.conf')
             self.db = DBEngine('/usr/src/Manager/'+self.config.get('Settings', 'dbfile'))
             self.db.initDB('/usr/src/Manager/'+self.config.get('Settings', 'sqlfile'))
      
             fDict = {'cur_status':'\'Installation failed!\'', 'state':'0'}
             cDict = {'state': '-1'}
	     self.db.updateRecords('ks_record', fDict, cDict)
          except dbException, e:
             print e.msg
             sys.exit()

      def status_update(self, mac_addr, ip_addr, status_text):
          log_path='/var/www/html/cloudfactory/logs/install/%s.log' % (mac_addr,) 
          if status_text = 'newinstall':
             try:
                os.remove(log_path)
             except Exception, e:
                pass

             os.mknod(log_path, 666 )
          else:
             f=open(log_path, 'wb');
             f.seek(0,2)
             f.write(status_text)
             f.close()
          return ''

      def status_notify(self, mac_addr, ip_addr, status_text):
         
          print 'Client Information'
          print 'MAC: %s IP: %s' % (mac_addr, ip_addr,)
          
	  fList = ['installer_mac_addr', 'state']
          cDict = {'installer_mac_addr': '\''+mac_addr+'\''}
	  limit = 1
	  try:
	     rList = self.db.selectRecords('ks_record', fList, cDict, limit)
	  except dbException, e:
	     print e.msg
	     sys.exit()

	  install_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
	  
          if len(rList) == 0:
	     rDict = {'id': 'NULL', 
	  	      'installer_mac_addr': '\''+mac_addr+'\'', 
		      'installer_ip_addr': '\''+ip_addr+'\'', 
		      'cur_status': '\''+status_text+'\'',
		      'state': '-1', 'install_time': '\''+install_time+'\''}
	     self.db.addRecord('ks_record', rDict)
             print 'Add installation record ok!\n' 
	  else:
	     if status_text.find("completed") != -1:
	        fDict = {"cur_status": '\''+status_text+'\'', 'state': '1'}
	        cDict = {'installer_mac_addr': '\''+mac_addr+'\''}
	        self.db.updateRecords('ks_record', fDict, cDict) 
	     elif status_text.find("fail") != -1:
	        fDict = {"cur_status": '\''+status_text+'\'', 'state': '0'}
	        cDict = {'installer_mac_addr': '\''+mac_addr+'\''}
	        self.db.updateRecords('ks_record', fDict, cDict) 
	     elif status_text.find("populated") != -1:
	        cDict = {'installer_mac_addr': '\''+mac_addr+'\''}
	        fDict = {"cur_status": '\''+status_text+'\'', 'state': '-1'}
	        self.db.updateRecords('ks_record', fDict, cDict)
	     else:
	        cDict = {'installer_mac_addr': '\''+mac_addr+'\''}
                #if int(rList[0][1]) == 1 or int(rList[0][1]) == 0:
	        fDict = {"cur_status": '\''+status_text+'\'', 'installer_ip_addr':'\''+ip_addr+'\'', 'state': '-1', 'install_time': '\''+install_time+'\''}
                #else:
	           #fDict = {"cur_status": '\''+status_text+'\'', 'state': '-1'}
	        self.db.updateRecords('ks_record', fDict, cDict)
             
             print 'Update installation status ok!\n' 

          return '' 

KSManager = KSMgr()
   
# Create server
server = SimpleXMLRPCServer((KSManager.config.get('Settings', 'host'), 
                             int(KSManager.config.get('Settings', 'port'))), 
                             requestHandler=RequestHandler,logRequests=False)
server.register_introspection_functions()

# RPC methods available for installer
server.register_function(KSManager.status_notify, 'status_notify')

print "Start server........\n"

# Run the server's main loop
server.serve_forever()

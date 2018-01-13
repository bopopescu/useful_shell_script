'''
Created on 2014-09-22

@author: Wei shun
'''

import os
import sys
import subprocess
import time
import ConfigParser
from SimpleXMLRPCServer import SimpleXMLRPCServer
from SimpleXMLRPCServer import SimpleXMLRPCRequestHandler
import xmlrpclib
import uuid
import base64
from SWMgr import *

interfaces_roles={
  "1":  " GE0/0/1                 ",
  "2":  " GE0/0/2                 ",
  "3":  " GE0/0/3                 ",
  "4":  " GE0/0/4     CF-eth0     ",
  "5":  " GE0/0/5     FW1-idrac   ",
  "6":  " GE0/0/6     FW1-eth0    ",
  "7":  " GE0/0/7     FW2-idrac   ",
  "8":  " GE0/0/8     FW2-eth0    ",
  "9":  " GE0/0/9     CS1-idrac   ",
  "10": "GE0/0/10     CS1-eth0    ",
  "11": "GE0/0/11     CS2-idrac   ",
  "12": "GE0/0/12     CS2-eth0    ",
  "13": "GE0/0/13     CS3-idrac   ",
  "14": "GE0/0/14     CS3-eth0    ",
  "15": "GE0/0/15     CS4-idrac   ",
  "16": "GE0/0/16     CS4-eth0    ",
  "17": "GE0/0/17     CS5-idrac   ",
  "18": "GE0/0/18     CS5-eth0    ",
  "19": "GE0/0/19     CS6-idrac   ",
  "20": "GE0/0/20     CS6-eth0    ",
  "21": "GE0/0/21     CS7-idrac   ",
  "22": "GE0/0/22     CS7-eth0    ",
  "23": "GE0/0/23                 ",
  "24": "GE0/0/24                 "
}

def_idrac_cfg = {
  "IP":       "192.168.0.120",
  "NETMASK":  "255.255.255.0",
  "GATEWAY":  "192.168.0.1",
  "USER":     "root",
  "PASSWORD": "calvin"
}

idrac_intf_cfg = {
   "5":   {"NAME": "FW1", "IP": "192.168.0.101"},
   "7":   {"NAME": "FW2", "IP": "192.168.0.102"},
   "9":   {"NAME": "CS1", "IP": "192.168.0.103"},
   "11":  {"NAME": "CS2", "IP": "192.168.0.104"},
   "13":  {"NAME": "CS3", "IP": "192.168.0.105"},
   "15":  {"NAME": "CS4", "IP": "192.168.0.106"},
   "17":  {"NAME": "CS5", "IP": "192.168.0.107"},
   "19":  {"NAME": "CS6", "IP": "192.168.0.108"},
   "21":  {"NAME": "CS7", "IP": "192.168.0.109"}
}

dhcp_info = {
  "IP" :     "10.1.0.0",
  "NETMASK": "255.255.0.0",
  "FW1":     "10.1.1.50",
  "FW2":     "10.1.1.51",
  "CS1":     "10.1.1.52",
  "CS2":     "10.1.1.53",
  "CS3":     "10.1.1.54",
  "CS4":     "10.1.1.55",
  "CS5":     "10.1.1.56",
  "CS6":     "10.1.1.57",
  "CS7":     "10.1.1.58"
}

# Restrict to a particular path.
class RequestHandler(SimpleXMLRPCRequestHandler):
      rpc_paths = ('/RPC2',)
      
# Kick Start Manager
class KSMgr:
      
      def __init__(self, conf_path):
      
          self.install_uuid = str(uuid.uuid1())
          self.def_cfg      = ConfigParser.ConfigParser()
          self.glb_cfg      = ConfigParser.ConfigParser()
          self.conf_path    = conf_path
          self.server_num   = 0
          self.def_cfg.read("default.conf")
          self.glb_cfg.read(conf_path)
     
      def install_update(self, server_role, logs):
          
          log_path='./%s/log/%s.log' % (self.install_uuid, server_role, )
        
          try:
              logcontent = base64.b64decode(logs['text']) 
             
              if logcontent == 'newinstall':
                 os.mknod(log_path, 666)
              elif logcontent == 'completeinstall':
                 print 'Installatin for server: ' + server_role + ' completed!'
                 self.server_num = self.server_num - 1
                 if self.server_num == 0:
                    raise Exception("\nAll servers have been finished installing!")

                 for k in idrac_intf_cfg:
                  
                     if idrac_intf_cfg[k]["NAME"] == server_role:
		        idrac_ip=ksmgr.get_parameter("GLOBAL", server_role + '_idrac_public_ip')
		        idrac_netmask=ksmgr.get_parameter("GLOBAL", server_role + '_idrac_public_netmask')
		        idrac_gateway=ksmgr.get_parameter("GLOBAL", server_role + '_idrac_public_gateway')
 
                        if idrac_ip == "" or idrac_netmask == "" or idrac_gateway == "":
                           pass
                        else:
                           ret = self.change_idrac_ip(idrac_intf_cfg[k]["IP"],
                                                      def_idrac_cfg["USER"],                 
                                                      def_idrac_cfg["PASSWORD"],
                                                      idrac_ip,
                                                      idrac_netmask,
                                                      idrac_gateway)
                           if ret is not True:
                              print 'Failed to change idrac public ip, you should change it manually!'
                                                         
              else:
                 with open(log_path, 'a') as logFile:
                      logFile.write(logcontent)

          except Exception, e:
                 print e
                 return False

          return True

      def getInstallLog(self, server_role):
          
          log_path='./%s/log/%s.log' % (self.install_uuid, server_role, )
        
          try:
             f=open(log_path, 'r')
             logstr=base64.b64encode(f.read())
             f.close()
             return logstr
        
          except Exception, e:
             logstr=base64.b64encode('No log received for this server so far, try again later!')
             return logstr

      def change_idrac_ip(self, old_ip, user, password, new_ip, new_netmask, new_gateway):

	  ctlCmd = './idracSetting.sh '+old_ip+' '+user+' '+password+' '+new_ip+' '+new_netmask+' '+new_gateway

	  try:
	       ctlProcess = subprocess.Popen(ctlCmd, shell=True, 
					     stdout=subprocess.PIPE,
					     stderr=subprocess.PIPE)
	       connError = False

	       for line in iter(ctlProcess.stderr.readline, b''):
		   if 'Connection timed out' in line or 'No route' in line or "ERROR" in line:
		       connError = True
		       break  

	       ctlProcess.communicate()

	       if ctlProcess.returncode == 0 and connError is not True:
		  return True
	       else:
		  return False

	  except Exception, e:
	        raise Exception("Exception when changing idrac ip!")
	        return False

      def get_nic_from_idrac(self, ip, user, password, role):

	  ctlCmd = './get_server_nic.sh ' + ip + ' ' + user + ' '+ password + ' ' + self.install_uuid + ' ' + role 

	  try:
	       ctlProcess = subprocess.Popen(ctlCmd, shell=True, 
					     stdout=subprocess.PIPE,
					     stderr=subprocess.PIPE)
	       connError = False

	       for line in iter(ctlProcess.stderr.readline, b''):
		   if 'Connection timed out' in line or 'No route' in line or "ERROR" in line:
		       connError = True
		       break  

	       ctlProcess.communicate()

	       if ctlProcess.returncode == 0 and connError is not True:
		  return True
	       else:
		  return False

	  except Exception, e:
	       raise Exception("Exception when getting server NIC info!")
	       return False

      def get_server_role(self, server_mac):
          
          ctlCmd = './get_server_role.sh ' + self.install_uuid + ' ' + server_mac
	  
          try:
	       ctlProcess = subprocess.Popen(ctlCmd, shell=True, 
					     stdout=subprocess.PIPE,
					     stderr=subprocess.PIPE)
	       connError = False
               role        = ""

               for line in iter(ctlProcess.stdout.readline, b''):
		   role = line.rstrip()
		   break 

	       ctlProcess.communicate()

               return role

	  except Exception, e:
	       raise Exception("Exception when getting server role info!")
	       return ""

      def config_dhcp_for_server(self, server_role, ip, loader, action="add"):
         
          ctlCmd = './dhcp_config.sh ' + self.install_uuid + ' ' + server_role + ' ' + ip + ' ' + loader + ' ' + action
          #print ctlCmd
          
          try:
               ctlProcess = subprocess.Popen(ctlCmd, shell=True, 
		 			     stdout=subprocess.PIPE,
					     stderr=subprocess.PIPE)
	       ctlProcess.communicate()
               
               if ctlProcess.returncode != 0:
	          raise Exception("dhcp_config.sh return error code: %d!" % (ctlProcess.returncode, ) )
                  
	  except Exception, e:
                 print e
	         raise Exception("Exception when configuring dhcp info!")
	

      def get_parameter(self, server_role, param_name):

          try:
                 if server_role != "GLOBAL":
                    return self.def_cfg.get(server_role, param_name)
                 
                 return self.glb_cfg.get(server_role, param_name)

          except Exception, e:
                 print e
                 print "section: " + server_role + " name: " + param_name
                 return ""
 
      def set_parameter(self, server_role, param_name, param_value):

          try:
                 self.def_cfg.set(server_role, param_name, param_value)
                 f = open("default.conf", 'w')
                 self.def_cfg.write(f)
                 f.close()
                 return True

          except Exception, e:
                 print e
                 return False

      def remote_start(self, idrac_ip, user, password):

	  ctlCmd = './remote_start.sh '+ idrac_ip + ' ' + user + ' ' + password

	  try:
	       ctlProcess = subprocess.Popen(ctlCmd, shell=True, 
					     stdout=subprocess.PIPE,
					     stderr=subprocess.PIPE)
	       connError = False

	       for line in iter(ctlProcess.stderr.readline, b''):
		   if 'Connection timed out' in line or 'No route' in line or "ERROR" in line:
		       connError = True
		       break  

	       ctlProcess.communicate()

               if ctlProcess.returncode == 0 and connError is not True:
                  return True
               else:
                  return False

          except Exception, e:
               raise Exception("Exception when starting remote server!")
               return False

      def warn_for_empty(self, server_role, name):

	  print  "%s for %s is empty, do you want to continue(y/n)?" % (name, server_role, )
		     
	  line = sys.stdin.readline()

	  if line == "y\n":
	     pass
	  elif line == "n\n":
	     print "Exit command by user!"    
             sys.exit(1)
	  else:
	     print "Invalid input, exit!"
             sys.exit(1)


if __name__ == '__main__':
 
     ksmgr = KSMgr("cloudfactory.conf")

     #ksmgr.get_nic_from_idrac(ip, user, password, 'FW1')
     #ksmgr.config_dhcp_for_server('FW1', ip, 'firewall/pxelinux.0', 'add')
     #ksmgr.get_nic_from_idrac(ip, user, password, 'CS1')
     #ksmgr.config_dhcp_for_server('CS1', ip, 'cserver/pxelinux.0', 'add')

     try:
	 server = SimpleXMLRPCServer(("10.86.11.161", 5555), 
				      requestHandler=RequestHandler,logRequests=False)

	 server.register_introspection_functions()

	 server.register_function(ksmgr.get_server_role, 'get_server_role')
	 server.register_function(ksmgr.get_parameter,   'get_parameter')
	 server.register_function(ksmgr.install_update,  'install_update')
	 server.register_function(ksmgr.getInstallLog,   'getInstallLog')

	 print "\nListen on port: 5555\n" 

	 server.serve_forever()
  
     except Exception,e :
         print e

     except KeyboardInterrupt, e:
         print "Ctrl-c pressed ..."

     ksmgr.config_dhcp_for_server('all', '0', '0', "delete") 
     
     sys.exit(0)

     idrac_list  = [5, 7, 9, 11, 13, 15, 17, 19, 21]
     remove_list = []
     
     swconn = SWConnector(ksmgr.get_parameter("SWITCH", "ip"), 
                          ksmgr.get_parameter("SWITCH", "user"), 
                          ksmgr.get_parameter("SWITCH", "password"))

     try:
        swconn.connect()
 
        # Show interfaces states and response to user input 
        while 1:
        
            idrac_list       = [5, 7, 9, 11, 13, 15, 17, 19, 21]
            remove_list      = []
            intf_list_states = ["UNKNOWN"] # Index 0 won't be used
            
            print "\nInterface   |     Role     |    State"
            print "---------------------------------------"

            # Interate through all interfaces
	    for intf in range(1, 25):
		e_num = swconn.get_interface_state(intf)
                intf_list_states.append(e_num)
		print interfaces_roles[str(intf)] + "       %s" % (state_desc[e_num], )

            # Select interfaces in idrac list those have not got ready
            for i in idrac_list:
                if intf_list_states[i] != STATE_UP or intf_list_states[i+1] != STATE_UP:
                   remove_list.append(i)   

            # Remove interfaces those not ready from idrac_list 
            for i in remove_list:
                idrac_list.remove(i)            
 
            print "\nCheck cables and find servers ready: \n"
            
            for i in idrac_list:
                print idrac_intf_cfg[str(i)]["NAME"] 

            print "\nType 'g' to start installation, 'e' to exit, or 'r' to recheck interfaces (g/e/r)?:"
                        
            line = sys.stdin.readline()

            if line == "g\n":
               pass

            elif line == "e\n":
               print "Exit command by user!"
               sys.exit(1)
           
            elif line == "r\n":
               continue

            else:
               print "Invalid input, exit!"
               sys.exit(1)

            print "\nCheck configuration for servers in 'cloudfactory.conf' ... \n"
            
            grid=ksmgr.get_parameter("GLOBAL", "grid")

            if grid == "":
               print "No GRID set in cloudfactory.conf!"
               sys.exit(1)

            for i in idrac_list:
                
                if "FW" in idrac_intf_cfg[str(i)]["NAME"]:
                   ip=ksmgr.get_parameter("GLOBAL", idrac_intf_cfg[str(i)]["NAME"] + "_public_ip")
                   if ip == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Public ip")
		   netmask=ksmgr.get_parameter("GLOBAL", idrac_intf_cfg[str(i)]["NAME"] + "_public_netmask")
                   if netmask == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Public netmask")
		   gateway=ksmgr.get_parameter("GLOBAL", idrac_intf_cfg[str(i)]["NAME"] + "_public_gateway")
                   if gateway == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Public gateway")
                   idrac_ip=ksmgr.get_parameter("GLOBAL", idrac_intf_cfg[str(i)]["NAME"] + "_idrac_public_ip")
                   if idrac_ip == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Idrac ip")
		   idrac_netmask=ksmgr.get_parameter("GLOBAL",idrac_intf_cfg[str(i)]["NAME"]+"_idrac_public_netmask")
                   if idrac_netmask == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Idrac netmask")
		   idrac_gateway=ksmgr.get_parameter("GLOBAL",idrac_intf_cfg[str(i)]["NAME"]+"_idrac_public_gateway")
                   if idrac_gateway == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Idrac gateway")
		   manage_ip=ksmgr.get_parameter("GLOBAL",idrac_intf_cfg[str(i)]["NAME"]+"_manage_ip")
                   if manage_ip == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Manage ip")
                else:
                   idrac_ip=ksmgr.get_parameter("GLOBAL", idrac_intf_cfg[str(i)]["NAME"] + "_idrac_public_ip")
                   if idrac_ip == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Idrac ip")
		   idrac_netmask=ksmgr.get_parameter("GLOBAL",idrac_intf_cfg[str(i)]["NAME"]+"_idrac_public_netmask")
                   if idrac_netmask == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Idrac netmask")
		   idrac_gateway=ksmgr.get_parameter("GLOBAL",idrac_intf_cfg[str(i)]["NAME"]+"_idrac_public_gateway")
                   if idrac_gateway == "":
                      ksmgr.warn_for_empty(idrac_intf_cfg[str(i)]["NAME"], "Idrac gateway")

	    print "Configuration checking completed!"

            break
	            
        print "\nStarting......\n"

        # Shutdown interfaces those not in valid state 
        for i in remove_list:
            if not swconn.set_interface_state(i, STATE_DOWN):
               raise Exception("Failed to set interface GE0/0/%d down" % (i, ))

        # Set all valid idrac port on Switch to down firstly 
        for i in idrac_list:
            if not swconn.set_interface_state(i, STATE_DOWN):
               raise Exception("Failed to set interface %d down" % (i, ))
            else:
               print "%s is set to DOWN state" % (interfaces_roles[str(i)], ) 

        print ''

        time.sleep(10)

        # Iterate all idrac ports on Switch and set them to UP state
        for intf_num in idrac_list:
            swconn.set_interface_state(intf_num, STATE_UP)
            time.sleep(50)
    
            # STATE_UP, with cable plugged in
            if STATE_UP == swconn.get_interface_state(intf_num):
               
               print "GE0/0/%d has been brought UP, idrac ip for '%s' will be changed to: %s" % (intf_num,                                                                                   idrac_intf_cfg[str(intf_num)]["NAME"], 
                                                                        idrac_intf_cfg[str(intf_num)]["IP"])
               
               ret = ksmgr.change_idrac_ip(def_idrac_cfg["IP"], 
                                           def_idrac_cfg["USER"],
                                           def_idrac_cfg["PASSWORD"], 
                                           idrac_intf_cfg[str(intf_num)]["IP"],
                                           def_idrac_cfg["NETMASK"],
                                           def_idrac_cfg["GATEWAY"])
               if ret is True:
                  print "Change idrac ip for %s to: %s successfully" % (idrac_intf_cfg[str(intf_num)]["NAME"], 
                                                                        idrac_intf_cfg[str(intf_num)]["IP"])
               else:
                  raise Exception("Failed to change idrac ip, try it later"%(idrac_intf_cfg[str(intf_num)]["NAME"],))

               time.sleep(30)
                
               ret = ksmgr.remote_start(idrac_intf_cfg[str(intf_num)]["IP"],
                                        def_idrac_cfg["USER"],
                                        def_idrac_cfg["PASSWORD"])

               if ret is True:
                  print "Start server '%s' successfully\n" % (idrac_intf_cfg[str(intf_num)]["NAME"], )
               else:
                  print "Failed to start server: %s\n" % (idrac_intf_cfg[str(intf_num)]["NAME"], )

               # Get NIC info from idrac device and store it for later use
               ret = ksmgr.get_nic_from_idrac(idrac_intf_cfg[str(intf_num)]["IP"],
                                              def_idrac_cfg["USER"],
                                              def_idrac_cfg["PASSWORD"],
                                              idrac_intf_cfg[str(intf_num)]["NAME"])
               if ret is not True:
                  raise Exception("Failed to get NIC info for server: %s"%(idrac_intf_cfg[str(intf_num)]["NAME"],))            
               # Configure DHCP for server
               if idrac_intf_cfg[str(intf_num)]["NAME"] in ['FW1', 'FW2']:
                  ksmgr.config_dhcp_for_server(idrac_intf_cfg[str(intf_num)]["NAME"],
                                               dhcp_info[idrac_intf_cfg[str(intf_num)]["NAME"]],
                                               'firewall/pxelinux.0', "add")
               else:
                  ksmgr.config_dhcp_for_server(idrac_intf_cfg[str(intf_num)]["NAME"],
                                               dhcp_info[idrac_intf_cfg[str(intf_num)]["NAME"]],
                                               'cserver/pxelinux.0', "add")
 
            # STATE_DOWN, no cable plugged in
            else:
               print "%s is not UP, ignore server: %s " % (interfaces_roles[str(intf_num)], 
                                                           idrac_intf_cfg[str(intf_num)]["NAME"],)
        ksmgr.server_num = len(idrac_list)

        for i in remove_list:
            swconn.set_interface_state(i, STATE_UP)

        swconn.disconnect()
        
     except Exception, e:
        print e

        ksmgr.config_dhcp_for_server('all', '0', '0', "delete") 

        # Set all idrac ports on Switch to UP state
        idrac_list  = [5, 7, 9, 11, 13, 15, 17, 19, 21]
        for i in idrac_list:
            swconn.set_interface_state(i, STATE_UP)

        swconn.disconnect()
        sys.exit(1) 
     
     except KeyboardInterrupt, e:
        print "Ctrl-c pressed ..."
 
        ksmgr.config_dhcp_for_server('all', '0', '0', "delete") 

        # Set all idrac ports on Switch to UP state
        idrac_list  = [5, 7, 9, 11, 13, 15, 17, 19, 21]
        for i in idrac_list:
            swconn.set_interface_state(i, STATE_UP)

        swconn.disconnect()
        sys.exit(1)

     print '\t***************************************************'
     print '''\tTo view installation progress, open a new 
              \n\tterminal and type 'install_report <server_role>',
              \n\tserver_role might be 'FW1', 'CS1' and so on.
           '''
     print '\t***************************************************'

     

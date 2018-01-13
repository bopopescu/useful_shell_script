'''
Created on 2015-06-09

@author: Wei shun
'''

import os
import sys
import time
import uuid
import base64
import syslog
import traceback
import threading
import xmlrpclib
import subprocess
import ConfigParser
from SimpleXMLRPCServer import SimpleXMLRPCServer,SimpleXMLRPCRequestHandler

g_lock = threading.Lock()

def except_line_info():

    for frame in traceback.extract_tb(sys.exc_info()[2]):
	fname,lineno,fn,text = frame
	except_string = "Error in %s, line: %d in func: %s"%(fname,lineno,fn,)
	return except_string


#Restrict to a particular path.
class RequestHandler(SimpleXMLRPCRequestHandler):
  rpc_paths = ('/RPC2',)
  

class HAService:
  
  def __init__(self):
  
      self.cfg = ConfigParser.ConfigParser()
      self.cfg.read("nodes.conf")

      self.role = self.cfg.get('LOCAL', 'role_type')

      self.heartbeat_interval = self.cfg.get('LOCAL', 'heartbeat_interval')

      #For MASTER
      self.san_ip = ''

      #Binding address for this node
      self.heartbeat_ip = self.cfg.get('LOCAL', 'heartbeat_ip')
   
      #For SLAVE node only
      self.master_ip = ''

      #For MASTER, this would be a list of dict, 
      #For SLAVE,this would be a list of str(ip)
      self.node_list = []

      print 'This is %s node......' % (self.role, )

      if self.role == 'MASTER':
	 self._init_master()

      elif self.role == 'SLAVE':
	 self._init_slave()

      elif self.role == 'STANDBY':
	 self._init_standby()

      else:
	 syslog.syslog(syslog.LOG_ERR, 'Error role: %s ' % self.role)
	 sys.exit(1)


  def _init_master(self): 

      del self.node_list[:]

      for section in self.cfg.sections():

	  if section == 'LOCAL':
	     continue
	 
	  node = {}

	  for option in self.cfg.options(section):

	      node[option] = self.cfg.get(section, option)
       
	  node['name'] = section
	  node['state'] = 'Normal'
	  node['unreach_count'] = 0

	  print 'Node: %s'%(node['heartbeat_ip'],)

	  self.node_list.append(node)

      self.san_ip = self.cfg.get('LOCAL', 'san_ip')

      #Broadcast cluster info to all SLAVE nodes
      self.broadcast_cluster_info()


  def _init_slave(self): 

      del self.node_list[:]

      self.master_ip = self.cfg.get('LOCAL', 'master_ip')

      if self.master_ip != '':
      
	 try:

	     xmlrpcObj = xmlrpclib.ServerProxy('http://'+self.master_ip \
					       + ':6666',allow_none=True)
	     node_list = xmlrpcObj.sync_cluster_info()

	     for node in node_list:
		 if node['heartbeat_ip'] not in self.node_list and \
					 node['heartbeat_ip'] != self.heartbeat_ip:
		    self.node_list.append(node['heartbeat_ip'])

	     xmlrpcObj.join_cluster({
				     'name': self.cfg.get('LOCAL', 'name'),
				     'lun': self.cfg.get('LOCAL', 'lun'),
				     'ssh_user': self.cfg.get('LOCAL', 'ssh_user'),
				     'role_type': self.cfg.get('LOCAL', 'role_type'),
				     'idrac_user': self.cfg.get('LOCAL', 'idrac_user'),
				     'heartbeat_ip': self.cfg.get('LOCAL', 'heartbeat_ip'),
				     'ssh_password': self.cfg.get('LOCAL', 'ssh_password'),
				     'idrac_password': self.cfg.get('LOCAL', 'idrac_password')
				    })

	 except Exception, e:

	     print e 
	     print except_line_info() 
	 
	     syslog.syslog(syslog.LOG_ERR, 'ccp Slave: %s '%(str(e),))
	     syslog.syslog(syslog.LOG_ERR, except_line_info())


  def _init_standby(self):

      del self.node_list[:]

      self.master_ip = self.cfg.get('LOCAL', 'master_ip')

      if self.master_ip != '':
      
	 try:

	     xmlrpcObj = xmlrpclib.ServerProxy('http://'+self.master_ip \
					       + ':6666',allow_none=True)
	     node_list = xmlrpcObj.sync_cluster_info()

	     for node in node_list:
		 if node not in self.node_list:
		    if node['role_type'] == 'SLAVE':
		       self.node_list.append(node)

		       #Create backup dirs for each node
		       os.system('mkdir -p /backup/' +
				  node['heartbeat_ip']+'/etc')
		       os.system('mkdir -p /backup/' +
				  node['heartbeat_ip']+'/server_config')
		       os.system('mkdir -p /backup/' +
				  node['heartbeat_ip']+'/domains')

	     xmlrpcObj.join_cluster({
				     'name' : self.cfg.get('LOCAL', 'name'),
				     'ssh_user' : self.cfg.get('LOCAL', 'ssh_user'),
				     'role_type' : self.cfg.get('LOCAL', 'role_type'),
				     'idrac_user' : self.cfg.get('LOCAL', 'idrac_user'),
				     'heartbeat_ip' : self.cfg.get('LOCAL', 'heartbeat_ip'),
				     'ssh_password' : self.cfg.get('LOCAL', 'ssh_password'),
				     'idrac_password' : self.cfg.get('LOCAL', 'idrac_password')
				    })

	 except Exception, e:

	     print e 
	     print except_line_info() 
	 
	     syslog.syslog(syslog.LOG_ERR, 'ccp Slave: %s '%(str(e),))
	     syslog.syslog(syslog.LOG_ERR, except_line_info())


  def whatTime(self):

      currentTime = long(time.time()*1000)
      return str(currentTime)


  def broadcast_cluster_info(self):
      '''Internal method for MASTER'''

      slave_info_list = []

      for node_info in self.node_list:
	  if node_info['role_type'] == 'SLAVE':
	     slave_info_list.append(node_info)

      for node in self.node_list:

	  if node['state'] == 'Normal' and node['unreach_count'] <= 0:

	      try:

		  xmlrpcObj = xmlrpclib.ServerProxy('http://'+node['heartbeat_ip']\
							+ ':6666', allow_none=True)
		  xmlrpcObj.set_master_ip(self.heartbeat_ip)
		  xmlrpcObj.add_nodes(slave_info_list)

	      except Exception, e:
		     
		  print e 
		  print except_line_info() 

		  syslog.syslog(syslog.LOG_ERR, 'ccp Master: %s '%(str(e),))
		  syslog.syslog(syslog.LOG_ERR, except_line_info())
	  

  def join_cluster(self, node_info):
      '''MASTER RPC method, called by SLAVE and STANDBY'''

      if node_info in self.node_list:
	 return None

      self.node_list.append(node_info)

      bExisted = False

      for section in self.cfg.sections():

	  if section == 'LOCAL':
	     continue

	  if section == node_info['name']:
	     bExisted = True
	     break

      if not bExisted:

	 try:
	      self.cfg.add_section(node_info['name'])

	      for key in node_info.keys():

		  if key == 'name':
		     continue

		  self.cfg.set(node_info['name'], key, node_info[key])
     
	      f = open('nodes.conf', 'w')
	      self.cfg.write(f)
	      f.close()

	 except Exception, e:
				   
	      print e 
	      print except_line_info() 

	      syslog.syslog(syslog.LOG_ERR, 'ccp Master: %s'%(str(e),))
	      syslog.syslog(syslog.LOG_ERR, except_line_info())

      #Don't write these to config file
      node_info['state'] = 'Normal'
      node_info['unreach_count'] = 0


  def sync_cluster_info(self):
      '''MASTER RPC method, called by SLAVE and STANDBY'''

      slave_info_list = []

      for node in self.node_list:

	  if node['role_type'] == 'STANDBY':
	     continue

	  slave_info_list.append(node)
   
      return slave_info_list


  def set_master_ip(self, heartbeat_ip):
      '''SLAVE RPC method, called by MASTER'''

      g_lock.acquire()
      del self.node_list[:]
      g_lock.release()

      self.master_ip = heartbeat_ip

      self.cfg.set('LOCAL', 
		   'master_ip', 
		    self.master_ip)

      try:
	 
	  f = open('nodes.conf', 'w')
	  self.cfg.write(f)
	  f.close()

      except Exception, e:
			       
	  print e 
	  print except_line_info() 

	  syslog.syslog(syslog.LOG_ERR, 'ccp Slave: %s'%(str(e),))
	  syslog.syslog(syslog.LOG_ERR, except_line_info())


  def reachable_notice(self, target, bReach):
      '''MASTER RPC method, called by SLAVE'''
      
      for node in self.node_list:

	  if target == node['heartbeat_ip']:

	     if bReach:
		if node['unreach_count'] > 0:
		   node['unreach_count'] -= 1
	     else:
		node['unreach_count'] += 1
	     
	     break


  def add_nodes(self, node_info_list):
      '''SLAVE, STANDBY RPC method, called by MASTER'''

      if self.role == 'SLAVE':

	 for node_info in node_info_list:

	     if node_info['heartbeat_ip'] not in self.node_list \
					  and node_info['role_type'] == 'SLAVE': 
		if node_info['heartbeat_ip'] != self.heartbeat_ip: 
		   self.node_list.append(node_info['heartbeat_ip'])

      elif self.role == 'STANDBY':

	 for node_info in node_info_list:
	     
	     if node_info not in self.node_list and node_info['role_type'] == 'SLAVE':
		self.node_list.append(node_info)                

      else:
	pass         


  def take_over(self, node_ip, san_ip, lun):
      '''STANDBY RPC method, called by MASTER'''

      #Discover iscsi target
      ret = os.system('iscsiadm -m discovery -t sendtargets -p '+san_ip)
      if ret:
	 print 'Failed to discover SAN'
	 syslog.syslog(syslog.LOG_ERR, 'Failed to discover SAN')

	 return None
     
      #Login iscsi LUN
      ret = os.system('iscsiadm -m node --login -T %s --portal %s'%(lun, san_ip))
      if ret:
	 print 'Failed to login SAN'
	 syslog.syslog(syslog.LOG_ERR, 'Failed to login SAN')
	 return None
      else:
	 print 'Login SAN, ip: %s' % (san_ip, )
	 syslog.syslog(syslog.LOG_INFO, 'Login SAN %s'%(san_ip,))

      ret = os.system('vgchange -ay vg')
      ret = os.system('vgchange -an vg')
      ret = os.system('vgchange -ay vg')
      if ret:
	 print 'Failed to activate vg'
	 syslog.syslog(syslog.LOG_ERR, 'Failed to activate vg')
	 return None
	
      #Restart VMs of this node on 'MASTER' node
      ret = os.system('cp -r /backup/' + node_ip + '/etc/. /vm/etc/')
      ret = os.system('cp -r /backup/' + node_ip + '/server_config/. /vm/server_config/')
      ret = os.system('cp -r /backup/' + node_ip +'/domains/. /var/lib/xend/domains/')

      if ret:
	 print 'Failed to copy VMs config file from /backup dir'
	 return None

      #Walks through '/vm/etc'
      for dirs, subdirs, files in os.walk('/vm/etc'):
	  for f in files:
	      if f.endswith('.xml'):
		 try:
		     ret = os.system('virsh create /vm/etc/%s'%(f,))
		     if ret != 0:
			print 'Failed to start VM with config file: %s' % (f,)
			syslog.syslog(syslog.LOG_ERR, 'ccp Master: Failed to start\
						       VM with configuration file:\
						      '%(f,))
		     else: 
			print 'Start VM with config file: %s' % (f,)
			syslog.syslog(syslog.LOG_INFO, 'ccp Master: start VM with'+\
						       'configuration file:%s'%(f,))
		 except Exception, e:
		     
		     print e
		     print except_line_info() 
		   
		     syslog.syslog(syslog.LOG_ERR, 'ccp Master: %s'%(str(e),))
		     syslog.syslog(syslog.LOG_ERR, except_line_info())


      #'STANDBY' becomes 'SLAVE'
      self.role = 'SLAVE'

      self.cfg.set('LOCAL', 'lun', lun)
      self.cfg.set('LOCAL', 'role_type', 'SLAVE')

      try:
	 
	  f = open('nodes.conf', 'w')
	  self.cfg.write(f)
	  f.close()

	  self._init_slave()

      except Exception, e:
			       
	  print e 
	  print except_line_info() 

	  syslog.syslog(syslog.LOG_ERR, 'ccp Standby: %s'%(str(e),))
	  syslog.syslog(syslog.LOG_ERR, except_line_info())


  def master_periodic_task(self):

     #Select a node to fence against 
     for node in self.node_list:

	 if node['role_type'] == 'STANDBY':
	    continue

	 print 'Node: %s, unreachable count: %d'%(node['heartbeat_ip'],node['unreach_count'],)

	 if node['unreach_count'] > 5:

	    ret = os.system('ping -c3 -W2 ' + node['heartbeat_ip'] + ' >/dev/null')
	    if ret != 0:
	       node['state'] = 'Abnormal'

	       print 'Node abnormal: %s' % (node['heartbeat_ip'], )
	       syslog.syslog(syslog.LOG_INFO, 'Node abnormal: %s'%(node['heartbeat_ip'],))
	    
	    break

     #Fail over handling               
     for node in self.node_list:

	 if node['state'] == 'Normal':
	    continue

	 print 'Node: %s state: Abnormal' % (node['heartbeat_ip'], )
	 syslog.syslog(syslog.LOG_INFO, 'Node: %s state: Abnormal' % (node['heartbeat_ip'],))
		
	 #Power off this node
	 ret = self.poweroff_node(node)
	 if ret:
	    print 'Failed to power off node: %s ' % (node['heartbeat_ip'], ) 
	    syslog.syslog(syslog.LOG_ERR, 'ccp Master: Failed to power off'\
					   +' node: ' + node['heartbeat_ip'])

	    #break

	 else:
	    print 'Power off node: %s' % (node['heartbeat_ip'],)
	    syslog.syslog(syslog.LOG_INFO, 'ccp Master: Power off node: '+ 
						     node['heartbeat_ip'])
	 
	 standby_nodes = []

	 for node_standby in self.node_list:
	     if node_standby['role_type'] == 'STANDBY':
		standby_nodes.append(node_standby)

	 if len(standby_nodes):

	    for standby_node in standby_nodes:

		try:
		    xmlrpcObj = xmlrpclib.ServerProxy('http://'+standby_node['heartbeat_ip']+\
								     ':6666', allow_none=True)
		    xmlrpcObj.take_over(node['heartbeat_ip'], self.san_ip, node['lun'])

		    print 'Standby node becomes SLAVE' 
		    syslog.syslog(syslog.LOG_INFO, 'Standby node becomes SLAVE')

		    standby_node['lun'] = node['lun']
		    standby_node['role_type'] = 'SLAVE'

		    self.cfg.remove_section(node['name'])                       

		    self.cfg.set(standby_node['name'], 'lun', node['lun'])                    
		    self.cfg.set(standby_node['name'], 'role_type', 'SLAVE')                    
    
		    f = open('nodes.conf', 'w')
		    self.cfg.write(f)
		    f.close()

		    #Select a standby node ramdomly
		    break
   
		except Exception, e:

		    print e 
		    print except_line_info() 

		    syslog.syslog(syslog.LOG_ERR, 'ccp Master: %s'%(str(e),))
		    syslog.syslog(syslog.LOG_ERR, except_line_info())

		    #Try another standby node
		    continue

	 else:
	    print 'No standby node available' 
	    syslog.syslog(syslog.LOG_INFO, 'No standby node available')


  def slave_periodic_task(self):

     if self.master_ip == '':
	return

     g_lock.acquire()

     for node_ip in self.node_list:

	 #Check connection with all other nodes
	 bReach = False
	 ret = os.system('ping -c3 -W2 ' + node_ip + ' >/dev/null')
	 if ret == 0:
	    bReach = True
	 else:
	    bReach = False
	    print 'Could not reach: %s' % (node_ip, )
	    syslog.syslog(syslog.LOG_ERR, 'Could not reach: %s' % (node_ip,))

	 #Send connection status to MASTER node
	 try:

	     xmlrpcObj = xmlrpclib.ServerProxy('http://' + self.master_ip\
						+':6666', allow_none=True)
	     xmlrpcObj.reachable_notice(node_ip, bReach)

	 except Exception, e:
		     
	     print e 
	     print except_line_info() 

	     syslog.syslog(syslog.LOG_ERR, 'ccp Slave: %s ' % (str(e), ) )
	     syslog.syslog(syslog.LOG_ERR, except_line_info())
     
     g_lock.release()


  def standby_periodic_task(self):

      #Syncronize configuration files from all nodes
      for node in self.node_list:

	   print 'Syncronize config file for Node: %s' % (node['heartbeat_ip'], )
	   syslog.syslog(syslog.LOG_INFO, 'Syncronize config file for Node: %s' \
					   % (node['heartbeat_ip'], ) )

	   auth_str  = 'sshpass -p %s ssh -l %s'%(node['ssh_password'],node['ssh_user'])

	   rsync_cmd = 'rsync -avz --rsh="' + auth_str + ' -o ConnectTimeout=10 -o '   +\
		       'StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null '     +\
		       '-o LogLevel=quiet" '+node['heartbeat_ip']+':/vm/etc/ /backup/' +\
		       node['heartbeat_ip'] + '/etc'

	   os.system(rsync_cmd + ' &') 

	   rsync_cmd = 'rsync -avz --rsh="' + auth_str + ' -o ConnectTimeout=10 -o '    +\
		       'StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o '   +\
		       'LogLevel=quiet" '+node['heartbeat_ip']+':/var/lib/xend/domains/'+\
		       ' /backup/' + node['heartbeat_ip'] + '/domains'

	   os.system(rsync_cmd + ' &') 

	   rsync_cmd = 'rsync -avz --rsh="' + auth_str + ' -o ConnectTimeout=10 -o '   +\
		       'StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null '     +\
		       '-o LogLevel=quiet" '+node['heartbeat_ip']+':/vm/server_config/'+\
		       ' /backup/' + node['heartbeat_ip'] + '/server_config'
	   
	   os.system(rsync_cmd + ' &') 


  def run_periodic_task(self):
      '''Main loop for MASTER, SLAVE, STANDBY'''

      loop_times = 0

      while True:
     
	    loop_times += 1           

	    #Sleep to void heavy heartbeat traffic         
	    time.sleep(float(self.heartbeat_interval))

	    if self.role == 'MASTER':    
	       self.master_periodic_task()

	       if loop_times % 5 == 0:
		   #Broadcast periodically, so SLAVE would get the latest 
		   #cluster info without knowing IP of MASTER in advance
		   self.broadcast_cluster_info()
		    
	    elif self.role == 'SLAVE':
		 self.slave_periodic_task()

	    elif self.role == 'STANDBY':
		 self.standby_periodic_task()

	    else:
	      syslog.syslog(syslog.LOG_ERR, 'Error role: %s ' % self.role)
	      sys.exit(1)

			       
  def poweroff_node(self, node):
      '''Internal method for MASTER'''

      idrac_ip       = ''
      idrac_user     = ''
      idrac_password = ''

      try:

	   idrac_ip       = node['idrac_ip']
	   idrac_user     = node['idrac_user']
	   idrac_password = node['idrac_password']
      
	   ctlCmd = './remote_poweroff.sh '   + idrac_ip    +\
					  ' ' + idrac_user  +\
					  ' ' + idrac_password

	   ctlProcess = subprocess.Popen(ctlCmd, shell=True, 
					 stdout=subprocess.PIPE,
					 stderr=subprocess.PIPE)
	   connError = False

	   for line in iter(ctlProcess.stderr.readline, b''):
	       if 'Connection timed out' in line or 'No route' in line\
						    or "ERROR" in line:
		   connError = True
		   break  

	   ctlProcess.communicate()

	   if ctlProcess.returncode == 0 and connError is not True:
	      return False
	   else:
	      return True

      except Exception, e:

	   syslog.syslog(syslog.LOG_ERR, 'In poweroff_node(): %s'%(str(e),))

	   return False
	   

if __name__ == '__main__':

 hasrv = HAService()

 try:

     server = SimpleXMLRPCServer((hasrv.heartbeat_ip, 6666), 
				  requestHandler=RequestHandler,
				  logRequests=False,
				  allow_none=True)

     server.register_introspection_functions()

     server.register_function(hasrv.whatTime, 'whatTime')
     server.register_function(hasrv.add_nodes, 'add_nodes')
     server.register_function(hasrv.take_over, 'take_over')
     server.register_function(hasrv.join_cluster, 'join_cluster')
     server.register_function(hasrv.set_master_ip, 'set_master_ip')
     server.register_function(hasrv.reachable_notice, 'reachable_notice')
     server.register_function(hasrv.sync_cluster_info, 'sync_cluster_info')

      
     server_thread = threading.Thread(target=server.serve_forever)
     server_thread.setDaemon(True)
     server_thread.start()
     
     print "\nListen on port: 6666\n" 
     syslog.syslog(syslog.LOG_INFO, 'ccp HA manager: Listen on port: 6666')

     hasrv.run_periodic_task()

 except Exception,e :
     
     print e
     print except_line_info()

     syslog.syslog(syslog.LOG_ERR, 'Exception caught: %s'%(str(e),))
     syslog.syslog(syslog.LOG_ERR, except_line_info())

     sys.exit(1)

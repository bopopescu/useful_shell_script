# -*- coding: utf-8 -*-
'''
Created on 2014-6-12

@author: Wei shun
'''
from single import SingleModel
import threading
import time
import xmlrpclib
import subprocess
import string
import os
import sys
from factoryDB import FactoryDBConnect
import base64
import traceback
import random, string
from config import *

testing_ip_suffix=174

def print_except_line():

    for frame in traceback.extract_tb(sys.exc_info()[2]):
        fname,lineno,fn,text = frame
        print "Error in %s on line: %d in func: %s" % (fname, lineno, fn, )

def generatePwd():

    myrg     = random.SystemRandom()
    alphabet = string.letters[0:52] + string.digits
    length   = 10
    pw = str().join(myrg.choice(alphabet) for _ in range(length))

    return pw

def send_except_msg_to_server(msg):

    xmlrpcObj = xmlrpclib.ServerProxy(cf_server.REQ_URL, allow_none=True)

    try:
	ret = xmlrpcObj.except_msg_from_agent(cf_agent.IDC_ID, msg)

	if ret['result'] != 0:
	   DEBUG and debug_print(ret['message'])

    except Exception, e:
	print_except_line()
        print e

class CFMgr(SingleModel):
    '''

    '''
    _lock = threading.Lock()
    dhcp_ip_dict = {}

    for i in range(20, 81):
	dhcp_ip_dict[i] = 0


    def __init__(self):
        '''
        The initialization module and corresponding DataBase
        Constructor
        '''
        SingleModel.__init__(self)


    def getParam(self, param):

        try:
	    mac        = param['macaddress']
	    cluster_id = str(param['cluster_id'])

	    if mac == '' and cluster_id == '':
		return ''

            factoryDB = FactoryDBConnect()

            condition = {}

	    if mac != '':
		condition['macaddress'] = mac
		param = factoryDB.queryTable(table_name.HPC_SERVER,condition)
	    elif cluster_id != '':
                if len(cluster_id) > 10:
		   condition['task_uuid'] = cluster_id
		   param = factoryDB.queryTable(table_name.HPC_TASK,condition)
                else:
		   condition['cluster_id']  = cluster_id
		   param = factoryDB.queryTable(table_name.HPC_SERVER,condition)

	    return param
        except Exception, e:
	    print_except_line()
            print e

    def install_update(self, device_id, logs):

        log_path='/opt/cloudvisor/Trace/logs/install/%s.log' % (device_id,)

        try:

            logcontent = base64.b64decode(logs['text'])

            if logcontent == 'newinstall':
               os.remove(log_path)
               os.mknod(log_path, 666)
            else:
               with open(log_path, 'a') as logFile:
                    logFile.write(logcontent)

        except Exception, e:
	    print_except_line()
            print e

        return True

    def getInstallLog(self, serverObj):

        log_path='/opt/cloudvisor/Trace/logs/install/'+str(serverObj.get('id', '-1'))+'.log'

        try:
           f=open(log_path, 'rb')
           logstr=base64.b64encode(f.read())
           f.close()
           logdlist=[]
           logdlist.append({
               'log':logstr
           })
           return logdlist

        except Exception, e:
	   print_except_line()
           logdlist=[]
           logdlist.append({
               'log':base64.b64encode('No installation log for this server')
           })
           return logdlist

    @classmethod
    def get_free_index(cls, macaddress):
        for k in cls.dhcp_ip_dict.keys():
            if cls.dhcp_ip_dict[k] == 0:
               cls.dhcp_ip_dict[k] = macaddress
               return int(k)
        return 0

    @classmethod
    def config_dhcp_for_server(cls, ip_dict):

	must_keys=["macaddress", "action"]

	for key in must_keys:
	    if not key in ip_dict.keys():
	       DEBUG and debug_print('No value set for %s' % key)
	       return False

	if ip_dict["action"] == dhcp_config.ADD:
	   must_keys=["server_name",  "bootfile"]
	   for key in must_keys:
	       if not key in ip_dict.keys():
		  DEBUG and debug_print('No value set for %s' % key)
		  return False

	   index = cls.get_free_index(ip_dict['macaddress'])
	   if index == 0:
	       DEBUG and debug_print('No ip address available!')
	       return False

	   fixed_ip = install_network_config.get("prefix") + str(index)

	   ctlCmd = './dhcp_config.sh '+ip_dict['action']+' '+ip_dict['macaddress']+' '+ip_dict['server_name']+' '+fixed_ip+' '+ip_dict['bootfile']

           try:
	       factoryDB = FactoryDBConnect()

               condition = {}
               condition['macaddress'] = ip_dict['macaddress']

               update_info = {}
               update_info['install_ip'] = fixed_ip

	       factoryDB.update_record(update_info, condition, table_name.HPC_SERVER)

           except Exception, e:
               print_except_line()
               print e
               send_except_msg_to_server(e.__str__())

	else:
	   ctlCmd = './dhcp_config.sh ' + ip_dict['action'] + ' ' + ip_dict['macaddress']

        DEBUG and debug_print(ctlCmd)
	try:
	     ctlProcess = subprocess.Popen(ctlCmd, shell=True,
					   stdout=subprocess.PIPE,
					   stderr=subprocess.PIPE)
	     ctlProcess.communicate()

	     if ctlProcess.returncode != 0:
		return False

	     return True

	except Exception, e:
	     print_except_line()
             print e
             send_except_msg_to_server(e.__str__())
	     return False

    @classmethod
    def unconfig_dhcp(cls, task_uuid):

	try:
	   factoryDB = FactoryDBConnect()

	   devices_info = {}
	   devices_info['task_uuid'] = task_uuid

	   devices, device_num = factoryDB.queryTable(table_name.HPC_SERVER, devices_info)

	   for device in devices:
	       if device['status'] != server_status.INITIAL:
		  ipconfig = {}
		  ipconfig['action']     = dhcp_config.DELETE
		  ipconfig['macaddress'] = device['macaddress']

		  if not cls.config_dhcp_for_server(ipconfig):
		     DEBUG and debug_print("Undo dhcp config for server: %s failed!" % (device['name'], ))

		  for k in cls.dhcp_ip_dict.keys():
		      if cls.dhcp_ip_dict[k] == device['macaddress']:
			 cls.dhcp_ip_dict[k] = 0

	       #condition = {}
	       #condition['macaddress'] = device['macaddress']

	       #factoryDB.delete_record(condition, table_name.HPC_SERVER)

           #For testing
           condition = {}
	   condition['task_uuid'] = task_uuid
	   factoryDB.delete_record(condition, table_name.HPC_TASK)

	except Exception, e:
	    print_except_line()
	    print e
            send_except_msg_to_server(e.__str__())


    @classmethod
    def update_server_status(cls, mac, status, comment=''):

	update_info = {}
	update_info['status']  = status
	update_info['comment'] = comment

	condition = {}
	condition['macaddress'] = mac

	try:
	   factoryDB = FactoryDBConnect()
	   factoryDB.update_record(update_info, condition, table_name.HPC_SERVER)

	except Exception, e:
	   print_except_line()
           print e
           send_except_msg_to_server(e.__str__())

    @classmethod
    def update_task_status(cls, task_uuid, status, comment=''):

	DEBUG and debug_print('\nTask: %s, status: %s\n' % (task_uuid, status, ))

	update_info = {}
	update_info['status']  = status
	update_info['comment'] = comment

	condition = {}
	condition['task_uuid'] = task_uuid

	xmlrpcObj = xmlrpclib.ServerProxy(cf_server.REQ_URL, allow_none=True)

	try:
	   factoryDB = FactoryDBConnect()
	   factoryDB.update_record(update_info, condition, table_name.HPC_TASK)

	except Exception, e:
	   print_except_line()
	   cls.unconfig_dhcp(task_uuid)
	   xmlrpcObj.update_task_status(task_uuid, status)
           send_except_msg_to_server(e.__str__())

	else:
	   if status == task_status.SUCCESS or status == task_status.FAILED:

              hpc_ret = {'task_uuid': task_uuid, 'status': status}

	      condition = {}
	      condition['task_uuid'] = task_uuid
   	      tasks, task_num = factoryDB.queryTable(table_name.HPC_TASK, condition)

              t_type = ''

              if task_num > 0:

		 t_type = tasks[0]['task_type']

                 if tasks[0]['task_type'] != task_type.DELETE:

		     hpc_ret['dns']                = tasks[0]['dns']
		     hpc_ret['cluster']            = {}
		     hpc_ret['cluster']['ip']      = tasks[0]['cluster_ip']
		     hpc_ret['cluster']['netmask'] = tasks[0]['netmask']
		     hpc_ret['cluster']['gateway'] = tasks[0]['gateway']
		     hpc_ret['cluster']['username']= tasks[0]['user']
		     hpc_ret['cluster']['password']= tasks[0]['password']


		     server_list = []
		     condition = {}
		     condition['task_uuid'] = task_uuid
		     servers, server_num = factoryDB.queryTable(table_name.HPC_SERVER, condition)

		     for server in servers:
			 server_list.append({
					     'uuid'        : server['uuid'],
					     'mac'         : server['macaddress'],
					     'ip'          : server['mgr_ip'],
					     'netmask'     : server['netmask'],
					     'gateway'     : server['gateway'],
					     'username'    : server['ssh_user'],
					     'password'    : server['ssh_password'],
					     'server_level': server['server_level']
					   })

		     hpc_ret['server_list'] = server_list

              if t_type != task_type.DELETE:
                 cls.unconfig_dhcp(task_uuid)

              #time.sleep(180) #Avoid modifying Phy Switch config too early
	      ret = xmlrpcObj.update_task_status(task_uuid, status, hpc_ret)
	      if ret['result'] != 0:
		 DEBUG and debug_print('Failed to notify Cloudfactory Server for task: %s, status: %s' % (task_uuid, status, ))


    @classmethod
    def power_control(cls, idrac_ip, idrac_user, idrac_password, action):

	ctlCmd = ""

	if action == power_state.START:
	   ctlCmd = './remote_start.sh '+ idrac_ip + ' ' + idrac_user + ' ' + idrac_password
	elif action == power_state.SHUTDOWN:
	   ctlCmd = './remote_shutdown.sh '+ idrac_ip + ' ' + idrac_user + ' ' + idrac_password
	else:
	   return False

        DEBUG and debug_print(ctlCmd)
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
	   print_except_line()
           print e
           send_except_msg_to_server(e.__str__())
           return False

    # Check arguments according to a specified dict pattern recursivelly,
    # dict in dict:{{}},dict in list:[{}],no support for list in list:[[]]
    def _args_check_ok(self, pattern_dict, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        try:
	    for key in pattern_dict.keys():
		if not key in args_dict.keys():
		   retMsg['result']  = enum_ret.ERROR
		   retMsg['message'] = err_msg.REQUIRED_ARGUMENT_ABSENT + '\'' + key + '\''
		   return (False, retMsg)

		elif type(pattern_dict[key]) is list: # dict in list
		     for lvalue in args_dict[key]:
			 if type(lvalue) is dict:
			    chk_ret = self._args_check_ok(pattern_dict[key][0], lvalue)
			    if chk_ret[0] is False:
			       return chk_ret

		elif type(pattern_dict[key]) is dict: # dict in dict
		     chk_ret = self._args_check_ok(pattern_dict[key], args_dict[key])
		     if chk_ret[0] is False:
			return chk_ret

	    return (True, retMsg)

        except Exception, e:
	    print_except_line()
            retMsg['result']  = enum_ret.ERROR
            retMsg['message'] = err_msg.INVALID_ARGUMENT_FORMAT
            return (False, retMsg)


    def request(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        must_key = {'task_type': ''}

        chk_ret = self._args_check_ok(must_key, args_dict)
        if chk_ret[0] is False:
           return chk_ret

        if args_dict['task_type'] == task_type.CREATE:
           retMsg = self.createCluster(args_dict)

        elif args_dict['task_type'] == task_type.ADD:
           retMsg = self.addServers(args_dict)

        elif args_dict['task_type'] == task_type.DELETE:
           retMsg = self.deleteServers(args_dict)

        elif args_dict['task_type'] == task_type.POWERON:
           retMsg = self.server_poweron(args_dict)

        elif args_dict['task_type'] == task_type.POWERSTATUS:
           retMsg = self.server_powerstatus(args_dict)

        elif args_dict['task_type'] == task_type.POWEROFF:
           retMsg = self.server_poweroff(args_dict)

        else:
            retMsg['result']  = enum_ret.ERROR
            retMsg['message'] = err_msg.INVALID_ARGUMENT_FORMAT

            return retMsg

        return retMsg


    def createCluster(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        chk_ret = self._args_check_ok(pattern_dict.CREATE, args_dict)
        if chk_ret[0] is False:
           return chk_ret[1]

        task_info              = {}
        task_info['task_uuid'] = args_dict['task_uuid']

        try:
           factoryDB = FactoryDBConnect()

           tasks, task_num = factoryDB.queryTable(table_name.HPC_TASK, task_info)
           if task_num > 0:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = err_msg.INVALID_TASK_ID
              return retMsg

           #Allocate IP and store server info into db
           ip_parts = args_dict['mgr_vlan']['range'][0].split('.')
           ip_subnet= ip_parts[0] + '.' + ip_parts[1] + '.' + ip_parts[2] + '.'
           ip_host  = int(ip_parts[3])
           for server in args_dict['server_list']:

               server_info = {}

               for k in server.keys():
                   if server[k] is not None:
                      server_info[k] = server[k]

               server_info['mgr_ip']       = ip_subnet + str(ip_host)
               server_info['idc_id']       = args_dict['idc_id']
               server_info['cluster_id']   = str(args_dict['cluster_id'])
               server_info['task_uuid']    = args_dict['task_uuid']
               server_info['netmask']      = args_dict['mgr_vlan']['netmask']
               server_info['gateway']      = args_dict['mgr_vlan']['gateway']
               server_info['ssh_user']     = 'root'
               server_info['ssh_password'] = 'powerall' #generatePwd()
               server_info['status']       = server_status.INITIAL

               # Delete existing server with the same mac address
               condition = {}
               condition['macaddress'] = server['macaddress']

               factoryDB.delete_record(condition, table_name.HPC_SERVER)

               result = factoryDB.insert_record(server_info, table_name.HPC_SERVER)

               ip_host = ip_host + 1

               DEBUG and debug_print('Add server:%s to cluster: %s\n' % (server_info['name'], args_dict['cluster_name']))

               if result[0]:
                  retMsg['result']  = enum_ret.OK
               else:
                  retMsg['result']  = enum_ret.ERROR
                  retMsg['message'] = ADD_SERVER_TO_DB_ERR

                  return retMsg

           #Store vlan info into db
           vlan_info = {}

           for k in args_dict['mgr_vlan'].keys():
               if k != 'range':
                  vlan_info[k] = str(args_dict['mgr_vlan'][k])

           result = factoryDB.insert_record(vlan_info, table_name.HPC_VLAN)

           row_id = result[1]

           if result[0]:
               retMsg['result']  = enum_ret.OK
           else:
               retMsg['result']  = enum_ret.ERROR
               retMsg['message'] = ADD_SERVER_TO_DB_ERR

               return retMsg

           #Task should be added until cluster info have been fully recorded
           task_info = {}

           task_info['task_uuid']    = args_dict['task_uuid']
           task_info['idc_id']       = args_dict['idc_id']
           task_info['cluster_id']   = str(args_dict['cluster_id'])
           task_info['cluster_type'] = args_dict['cluster_type']
           task_info['cluster_name'] = args_dict['cluster_name']
           task_info['dns']          = args_dict['dns']
           task_info['san_ip']       = args_dict['storageinfo']['san_ip']
           task_info['san_target']   = args_dict['storageinfo']['san_target']
           task_info['san_user']     = args_dict['storageinfo']['san_user']
           task_info['san_password'] = args_dict['storageinfo']['san_password']
           task_info['mgr_vlan_id']  = str(row_id)
           task_info['status']       = task_status.INITIAL
           task_info['task_type']    = task_type.CREATE

           #Determine cluster ip
           if task_info['cluster_type'] == cluster_type.XENSERVER:
              condition = {}
              condition['server_level'] = server_level.XENSERVER_MASTER
              condition['task_uuid']    = task_info['task_uuid']

              devices, devices_num = factoryDB.queryTable(table_name.HPC_SERVER, condition)
              if devices_num > 0:
                 task_info['cluster_ip']  = devices[0]['mgr_ip']
                 task_info['netmask']     = devices[0]['netmask']
                 task_info['gateway']     = devices[0]['gateway']
                 task_info['user']        = devices[0]['ssh_user']
                 task_info['password']    = devices[0]['ssh_password']

           elif task_info['cluster_type'] == cluster_type.VSPHERE:
              task_info['cluster_ip'] = ip_subnet + str(ip_host)

              condition = {}
              condition['server_level'] = server_level.VSPHERE_MASTER
              condition['task_uuid']    = task_info['task_uuid']

              devices, devices_num = factoryDB.queryTable(table_name.HPC_SERVER, condition)
              if devices_num > 0:
                 task_info['netmask']     = devices[0]['netmask']
                 task_info['gateway']     = devices[0]['gateway']
                 task_info['user']        = devices[0]['ssh_user']
                 #task_info['password']    = devices[0]['ssh_password']
                 task_info['password']    = 'vmware'

           DEBUG and debug_print('New task:\n')
           DEBUG and debug_print(task_info)
           result = factoryDB.insert_record(task_info, table_name.HPC_TASK)

           if result[0]:
              retMsg['result']  = enum_ret.OK
              DEBUG and debug_print('New task added: \n')
           else:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = err_msg.ADD_TASK_ERR

              return retMsg

           return retMsg

        except Exception, e:
	   print_except_line()
           print e
           send_except_msg_to_server(e.__str__())

    def addServers(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        chk_ret = self._args_check_ok(pattern_dict.ADD, args_dict)
        if chk_ret[0] is False:
           return chk_ret[1]

        server_info               = {}
        server_info['idc_id']     = args_dict["idc_id"]
        server_info['cluster_id'] = str(args_dict["cluster_id"])

        try:
           factoryDB = FactoryDBConnect()

           servers, server_num = factoryDB.queryTable(table_name.HPC_SERVER, server_info)

           if server_num <= 0:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = err_msg.CLUSTER_NOT_EXIST
              return retMsg

           #Update Cluster
           for server in args_dict['server_list']:

		server_info = {}
		for k in server.keys():
		    server_info[k] = server[k]

		server_info['ssh_user']     = 'root'
		server_info['ssh_password'] = 'powerall' #generatePwd()

		server_info['status'] = server_status.INITIAL

		result = factoryDB.insert_record(server_info, table_name.HPC_SERVER)

		if result[0]:
		   retMsg['result']  = enum_ret.OK
		   DEBUG and debug_print('Update, add server:%s to cluster-----\n' % (server_info['name'], ))
		else:
		   retMsg['result']  = enum_ret.ERROR
		   retMsg['message'] = err_msg.ADD_SERVER_TO_CLUSTER_FAILED

		   return retMsg


           #Add task to update cluster
           task_info               = {}
           task_info['task_uuid']  = args_dict["task_uuid"]
           task_info['idc_id']     = args_dict["idc_id"]
           task_info['cluster_id'] = str(args_dict["cluster_id"])
           task_info['status']     = task_status.INITIAL
           task_info['task_type']  = task_type.ADD

           result = factoryDB.insert_record(task_info, table_name.HPC_TASK)

           if result[0]:
               retMsg['result']  = enum_ret.OK
           else:
               retMsg['result']  = enum_ret.ERROR
               retMsg['message'] = err_msg.ADD_TASK_ERR

               return retMsg

           return retMsg

        except Exception, e:
	   print_except_line()
           print e
           send_except_msg_to_server(e.__str__())

    def deleteServers(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        chk_ret = self._args_check_ok(pattern_dict.DELETE, args_dict)
        if chk_ret[0] is False:
           return chk_ret[1]

        server_info               = {}
        server_info['idc_id']     = args_dict["idc_id"]
        server_info['cluster_id'] = str(args_dict["cluster_id"])

        try:
           factoryDB = FactoryDBConnect()

           servers, server_num = factoryDB.queryTable(table_name.HPC_SERVER, server_info)

           if server_num <= 0:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = err_msg.CLUSTER_NOT_EXIST
              return retMsg
           else:
              if len(args_dict['server_list']) == 0:

                 update_info = {}
                 update_info['status'] = server_status.DELETED

                 condition = {}
                 condition['idc_id']     = args_dict['idc_id']
                 condition['cluster_id'] = str(args_dict['cluster_id'])

                 factoryDB.update_record(update_info, condition, table_name.HPC_SERVER)

              else:

                 for server in args_dict['server_list']:
                     update_info = {}
                     update_info['status'] = server_status.DELETED

                     condition = {}
                     condition['macaddress'] = server['macaddress']

                     factoryDB.update_record(update_info, condition, table_name.HPC_SERVER)

              task_info               = {}
              task_info['task_uuid']  = args_dict['task_uuid']
              task_info['idc_id']     = args_dict['idc_id']
              task_info['cluster_id'] = str(args_dict['cluster_id'])
              task_info['status']     = task_status.INITIAL
              task_info['task_type']  = task_type.DELETE

              result = factoryDB.insert_record(task_info, table_name.HPC_TASK)

              if result[0]:
                 retMsg['result']  = enum_ret.OK
              else:
                 retMsg['result']  = enum_ret.ERROR
                 retMsg['message'] = err_msg.ADD_TASK_ERR

              return retMsg

        except Exception, e:
	      print_except_line()
              print e
              send_except_msg_to_server(e.__str__())

    def server_poweron(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        chk_ret = self._args_check_ok(pattern_dict.POWERON, args_dict)
        if chk_ret[0] is False:
           return chk_ret[1]

        server_info               = {}
        server_info['macaddress'] = args_dict["macaddress"]

        try:
           factoryDB = FactoryDBConnect()

           servers, server_num = factoryDB.queryTable(table_name.HPC_SERVER, server_info)

           if server_num <= 0:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = err_msg.SERVER_NOT_EXISTED
              return retMsg

           ret_powerstatus = self.server_powerstatus(args_dict)

           if ret_powerstatus['return'] == 'ON':
              retMsg['result'] = enum_ret.OK
              return retMsg

           ctlCmd = './remote_poweron.sh '+ servers[0]['idrac_ip'] + ' ' + servers[0]['idrac_user'] + ' ' + servers[0]['idrac_password']

           ctlProcess = subprocess.Popen(ctlCmd, shell=True,
					 stdout=subprocess.PIPE,
					 stderr=subprocess.PIPE)

	   ctlProcess.communicate()

           retMsg['result'] = enum_ret.OK
           return retMsg

        except Exception, e:
	    print_except_line()
            print e
            send_except_msg_to_server(e.__str__())


    def server_powerstatus(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        chk_ret = self._args_check_ok(pattern_dict.POWERSTATUS, args_dict)
        if chk_ret[0] is False:
           return chk_ret[1]

        server_info               = {}
        server_info['macaddress'] = args_dict["macaddress"]

        try:
           factoryDB = FactoryDBConnect()

           servers, server_num = factoryDB.queryTable(table_name.HPC_SERVER, server_info)

           if server_num <= 0:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = err_msg.SERVER_NOT_EXISTED
              return retMsg

           ctlCmd = './remote_powerstatus.sh '+ servers[0]['idrac_ip'] + ' ' + servers[0]['idrac_user'] + ' ' + servers[0]['idrac_password']

           ctlProcess = subprocess.Popen(ctlCmd, shell=True,
					 stdout=subprocess.PIPE,
					 stderr=subprocess.PIPE)

	   for line in iter(ctlProcess.stdout.readline, b''):
               if 'ON' in line:
                  retMsg['result'] = enum_ret.OK
                  retMsg['return'] = 'ON'
               elif 'OFF' in line:
                  retMsg['return'] = 'OFF'
                  retMsg['result'] = enum_ret.OK
               else:
                  retMsg['result'] = enum_ret.ERROR

	   ctlProcess.communicate()

           return retMsg

        except Exception, e:
	    print_except_line()
            print e
            send_except_msg_to_server(e.__str__())


    def server_poweroff(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        chk_ret = self._args_check_ok(pattern_dict.POWEROFF, args_dict)
        if chk_ret[0] is False:
           return chk_ret[1]

        server_info               = {}
        server_info['macaddress'] = args_dict["macaddress"]

        try:
           factoryDB = FactoryDBConnect()

           servers, server_num = factoryDB.queryTable(table_name.HPC_SERVER, server_info)

           if server_num <= 0:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = err_msg.SERVER_NOT_EXISTED
              return retMsg

           ret_powerstatus = self.server_powerstatus(args_dict)

           if ret_powerstatus['return'] == 'OFF':
              retMsg['result'] = enum_ret.OK
              return retMsg

           ctlCmd = './remote_poweroff.sh '+ servers[0]['idrac_ip'] + ' ' + servers[0]['idrac_user'] + ' ' + servers[0]['idrac_password']

           ctlProcess = subprocess.Popen(ctlCmd, shell=True,
					 stdout=subprocess.PIPE,
					 stderr=subprocess.PIPE)

	   ctlProcess.communicate()

           retMsg['result'] = enum_ret.OK
           return retMsg

        except Exception, e:
	    print_except_line()
            print e
            send_except_msg_to_server(e.__str__())


    @classmethod
    def statusNotify(cls, mac, status, comment=''):

        if mac == '' or status == '':
           return None

        status = base64.b64decode(status)
        cls.update_server_status(mac, status)

        try:
            condition = {}
            condition['macaddress'] = mac

            factoryDB = FactoryDBConnect()

            devices, device_num = factoryDB.queryTable(table_name.HPC_SERVER, condition)

            if device_num > 0:
               DEBUG and debug_print('Status notify from (' + mac + ')' + devices[0]['name'] + ': ' + status)
               condition = {}
               condition['task_uuid'] = devices[0]['task_uuid']
               devices, device_num    = factoryDB.queryTable(table_name.HPC_SERVER, condition)

               installed_num = 0

               for device in devices:
                   if device['status'] == server_status.FAILED:
                      cls.update_task_status(device['task_uuid'],task_status.FAILED,device['name']+': '+comment)
                      break
                   elif device['status'] == server_status.INSTALLED:
                      installed_num = installed_num + 1

               if installed_num == device_num:
                  cls.update_task_status(devices[0]['task_uuid'], task_status.SUCCESS)

        except Exception, e:
	    print_except_line()
            print e
            send_except_msg_to_server(e.__str__())

    @classmethod
    def process_new_task(cls):

	try:
	    factoryDB = FactoryDBConnect()

	    task_info = {}
	    task_info['status'] = task_status.INITIAL

	    tasks, task_num = factoryDB.queryTable(table_name.HPC_TASK, task_info)

	    if task_num <= 0:
	       return


	    for task in tasks:
		device_info = {}
		device_info['cluster_id'] = str(task['cluster_id'])
		device_info['idc_id']     = str(task['idc_id'])
		devices, device_num       = factoryDB.queryTable(table_name.HPC_SERVER, device_info)

		if device_num <= 0:
		   DEBUG and debug_print('No server in cluster: ' + str(task['cluster_id']) + '\n')
		   continue

		#****************************Create cluster**************************#
		if task['task_type'] == task_type.CREATE :

		   DEBUG and debug_print('*****************Create cluster*****************\n')

 	           #****For testing purpose****
                   #cls.update_task_status(task['task_uuid'], task_status.SUCCESS)
                   #return
                   #**************************

		   #change task status to 'progress'
		   cls.update_task_status(task['task_uuid'], task_status.PROGRESS)

		   for device in devices:
		       ipconfig = {}
		       ipconfig['action']      = dhcp_config.ADD
		       ipconfig['server_name'] = device['uuid']
		       ipconfig['nameserver']  = task['dns']
		       ipconfig['macaddress']  = device['macaddress']
		       ipconfig['bootfile']    = task['cluster_type'] + '/pxelinux.0'

                       if task['cluster_type'] == cluster_type.CCP:
		          ipconfig['bootfile'] = device['server_level'] + '/pxelinux.0'

		       if not cls.config_dhcp_for_server(ipconfig):
			  DEBUG and debug_print('Failed  to config dhcp for server: %s' % (device['name'], ))

			  #change task status to 'failed'
			  cls.update_task_status(task['task_uuid'], task_status.FAILED)

			  break

		       DEBUG and debug_print('Configure /etc/dhcpd.conf for %s\n' % (device['name'], ))

		       cls.update_server_status(device['macaddress'], server_status.PROGRESS)

		       #Boot server from PXE immediately
		       if not cls.power_control(device['idrac_ip'],
				  	        device['idrac_user'],
					        device['idrac_password'],
					        power_state.START):
			  #change task status to 'failed'
			  cls.update_task_status(task['task_uuid'], task_status.FAILED)

			  DEBUG and debug_print('Could no start server "' + device['name'] + '" remotely\n')

			  break

		       DEBUG and debug_print('Start server "' + device['name'] + '" remotely-----\n')

		#****************************Destroy cluster**************************#
		elif task['task_type'] == task_type.DELETE:

		     DEBUG and debug_print('*********************Delete cluster************************\n')

		     for device in devices:

			 if device['status'] == server_status.DELETED:
			    ipconfig = {}
			    ipconfig['action']     = dhcp_config.DELETE
			    ipconfig['macaddress'] = device['macaddress']

			    #if not cls.config_dhcp_for_server(ipconfig):
			    #   print 'Failed  to remove dhcp info for server: %s' % (device['name'], )

		 	    if not cls.power_control(device['idrac_ip'],
				 		     device['idrac_user'],
						     device['idrac_password'],
						     power_state.SHUTDOWN):
			       DEBUG and debug_print('Failed to shutdown server: %s' % (device['name'], ))
			    else:
			       DEBUG and debug_print('Shutdown server: %s' % (device['name'], ))

			    condition = {}
			    condition['macaddress'] = device['macaddress']

			    factoryDB.delete_record(condition, table_name.HPC_SERVER)

		     #change task status to 'success'
		     cls.update_task_status(task['task_uuid'], task_status.SUCCESS)

		#****************************Update cluster**************************#
		elif task['task_type'] == task_type.ADD:

		     DEBUG and debug_print('*********************Update cluster************************\n')

		     cls.update_task_status(task['task_uuid'], task_status.PROGRESS)

		     for device in devices:

			 if device['status'] == server_status.INITIAL:

			    #Add IP info to /etc/dhcpd.conf
			    ipconfig = {}
			    ipconfig['action']      = dhcp_config.ADD
			    ipconfig['macaddress']  = device['macaddress']
			    ipconfig['server_name'] = device['uuid']
		            ipconfig['nameserver']  = task['dns']
			    ipconfig['bootfile']    = task['cluster_type'] + '/pxelinux.0'

                            if task['cluster_type'] == cluster_type.CCP:
           		       ipconfig['bootfile'] = device['server_level'] + '/pxelinux.0'

			    if not cls.config_dhcp_for_server(ipconfig):
			       #change task status to 'failed'
			       cls.update_task_status(task['task_uuid'], task_status.FAILED)

			       DEBUG and debug_print('Failed  to config dhcp for server: %s' % (device['name'], ))

			       break

			    DEBUG and debug_print('Config in /etc/dhcpd.conf for %s\n' % (device['name'], ))

			    cls.update_server_status(device['macaddress'], server_status.PROGRESS)

			    #Boot server from PXE immediately
			    if not cls.power_control(device['idrac_ip'],
				  		     device['idrac_user'],
						     device['idrac_password'],
						     power_state.START):

			       #change task status to 'failed'
			       cls.update_task_status(task['task_uuid'], task_status.FAILED)

			       DEBUG and debug_print('Could no start server "' + device['name'] + '" remotely\n')

			       break

                            DEBUG and debug_print('Start server "' + device['name'] + '" remotely-----\n')

	except Exception, e:
	    print_except_line()
	    print e
            send_except_msg_to_server(e.__str__())


    @classmethod
    def process_pending_task(cls):

	try:
	    factoryDB = FactoryDBConnect()

	    task_info = {}
	    task_info['status'] = task_status.PROGRESS

	    tasks, task_num = factoryDB.queryTable(table_name.HPC_TASK, task_info)

	    if task_num <= 0:
	       return

	    for task in tasks:
		time_create = int(time.mktime(task['create_time'].timetuple()))
		time_now    = int(time.time())

		if time_now - time_create < TASK_TIMEOUT:
		   continue

		device_info = {}
		device_info['task_uuid'] = task['task_uuid']

		devices, device_num = factoryDB.queryTable(table_name.HPC_SERVER, device_info)

		comment = 'Server: '

		for device in devices:
		    if device['status'] != server_status.INSTALLED:
		       comment = comment + device['name'] + ', '

		comment = comment + ' install time out'

		cls.update_task_status(task['task_uuid'], task_status.FAILED, comment)

	except Exception, e:
	    print_except_line()
	    print e
            send_except_msg_to_server(e.__str__())

    @classmethod
    def task_process(cls):

	while True:
	    cls.process_new_task()
	    cls.process_pending_task()

            time.sleep(2)


    @classmethod
    def signal_handler(cls, signum, frame):

	DEBUG and debug_print('In custom signal handler for SIGTERM')

	if signum == signal.SIGTERM:
	   factoryDB = FactoryDBConnect()
	   tasks, task_num = factoryDB.queryTable(table_name.HPC_TASK, '')
	   for task in tasks:
	       if task['status'] != task_status.SUCCESS:
		  cls.update_task_status(task['task_uuid'], task_status.FAILED)


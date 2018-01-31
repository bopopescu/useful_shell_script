# -*- coding: utf-8 -*-

import threading
from twisted.internet import threads
import xmlrpclib
import time
import string
import os
import sys
import base64
import smtplib
import traceback
import uuid
import hashlib
import hmac
import sha
from single import SingleModel
from factoryDB import FactoryDBConnect
from config import *

def call_hpcmgr_back(args_dict):
   s=xmlrpclib.ServerProxy(hpc_mgr.REQ_URL)
   print 'Send cluster info to HPC Manager:'
   print args_dict
       
   time.sleep(60) 
   s.afterCreateCloudFactory(args_dict)

def genStoken(access_uuid,
              access_key,
              method_name,
              timeoffset=0,
              service_uuid="",
              resource_uuid="",
              task_uuid="",
              task_key="",
              api_version="0.1"):
    '''
    generate the security token object of Cloudfactory service
    @param access_uuid:
    @param access_key:
    @param method_name:
    @param timeoffset: adapted timestamp = int(time.time())+timeoffset
    @param service_uuid:
    @param task_uuid:
    @param task_key:
    @return: security token object
    '''

    timestamp = int(time.time())+timeoffset
    security_string = "<"+str(timestamp)+"><"+ method_name+">"
    security_hash   = base64.encodestring(hmac.new(access_key.decode('utf8').encode('cp850'), security_string, sha).hexdigest()).strip()
    task_hash = ""
    if task_uuid != "":
       task_hash  = base64.encodestring(hmac.new(access_key, security_string, sha).hexdigest()).strip()
    stoken = {
             "timestamp":timestamp,
             "access_uuid":access_uuid,
             "service_uuid":service_uuid,
             "security_hash":security_hash,
             "task_token":{
                   "task_uuid":task_uuid,
                   "resource_uuid":resource_uuid,
                   "task_hash":task_hash
              },
             "session_id":"",
             "return_type":""
             }
    return stoken

def print_except_line():
            
    for frame in traceback.extract_tb(sys.exc_info()[2]):
        fname,lineno,fn,text = frame
        DEBUG and debug_print( "Error in %s on line: %d in func: %s" % (fname, lineno, fn, ) )


class CFServerMgr(SingleModel):
    '''

    '''
    _lock = threading.Lock()
    task_list = []
    
    def __init__(self):
        SingleModel.__init__(self)

    def whatTime(self):
    
       currentTime = long(time.time()*1000)
       return str(currentTime)

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
		   retMsg['message'] = ret_msg.REQUIRED_ARGUMENT_ABSENT + '\'' + key + '\''
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
            retMsg['message'] = 'Invalid argument format!'

            return (False, retMsg)

    def except_msg_from_agent(self, agent_id, msg):
 
        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''
       
        try:
            
            factoryDB = FactoryDBConnect()
 
	    condition = {}
            condition['idc_id'] = agent_id
            
	    agents, agent_num = factoryDB.queryTable(table_name.CF_AGENT, condition)
            admin_email = agents[0]['admin_email']
            
            smtpObj = smtplib.SMTP(smtp_info.HOST, smtp_info.PORT)

            msg = smtp_info.SUBJECT + agent_id + "\n\n" + msg 
            smtpObj.sendmail(smtp_info.SENDER, admin_email, msg)         

            DEBUG and debug_print("Sent email successfully")

            alert_info = {}
            alert_info['idc_id']  = agent_id
            alert_info['message'] = msg
            
            #factoryDB.insert_record(alert_info, table_name.CF_ALERT)

            retMsg['result'] = enum_ret.OK

            return retMsg

        except Exception, e:
            print_except_line()
            print e
 
            retMsg['result']  = enum_ret.ERROR
            retMsg['message'] = e.__str__()

            return retMsg

    def register(self, args_dict):

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        pattern_dict = {
                        'idc_id'      : '',
                        'req_url'     : '',
                        'admin_email' : ''
                       }
 
        chk_ret = self._args_check_ok(pattern_dict, args_dict)
        if chk_ret[0] is False:
           return chk_ret[1]

        try:
           factoryDB = FactoryDBConnect()

           condition = {}
           condition['idc_id'] = args_dict['idc_id']

	   idcs, idc_num = factoryDB.queryTable(table_name.CF_AGENT, condition)

           if idc_num > 0:
              retMsg['result']  = enum_ret.OK
              retMsg['message'] = ret_msg.REGISTRATION_OK
              return retMsg
           
           agent_info = {}
           for k in args_dict.keys():
               agent_info[k] = args_dict[k]

           result = factoryDB.insert_record(agent_info, table_name.CF_AGENT)

	   if result[0]:
	      retMsg['result']  = enum_ret.OK
              retMsg['message'] = ret_msg.REGISTRATION_OK
	   else:
	      retMsg['result']  = enum_ret.ERROR
	      retMsg['message'] = ADD_AGENT_TO_DB_ERR 
      
	   return retMsg     

        except Exception, e:
           print_except_line()
           print e
       

    def request(self, stoken, args_dict):

        DEBUG and debug_print('task arguments:')
        DEBUG and debug_print(args_dict)
  
        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

        #For testing
        #args_dict['cluster_type'] = cluster_type.XENSERVER

        #Check security token 
        must_keys = {'access_uuid':'', 'security_hash':'', 'timestamp':''}

        chk_ret = self._args_check_ok(must_keys, stoken)
        if chk_ret[0] is False:
           DEBUG and debug_print(chk_ret[1])
           return chk_ret[1]

        timestamp = int(time.time())

        DEBUG and debug_print('client: ' + str(stoken['timestamp']))
        DEBUG and debug_print('server: ' + str(timestamp))

        #*************Check security token************************
        if (timestamp - int(stoken['timestamp'])) > TOKEN_EXPIRE_TIME:
           retMsg['result']  = enum_ret.ERROR
           retMsg['message'] = ret_msg.INVALID_TIME_STAMP
           return retMsg

        if access_uuid != stoken['access_uuid']:         
           retMsg['result']  = enum_ret.ERROR
           retMsg['message'] = ret_msg.INVALID_ACCESS_UUID
           return retMsg

        security_string = "<"+str(stoken['timestamp'])+"><"+ "request" +">"
        security_hash = base64.encodestring(hmac.new(access_key.decode('utf8').encode('cp850'), security_string, sha).hexdigest()).strip()
 
        if security_hash != stoken['security_hash']:         
           retMsg['result']  = enum_ret.ERROR
           retMsg['message'] = ret_msg.INVALID_SECURITY_HASH
           return retMsg
        
        #*************Check security token End************************

        #For testing
        #retMsg['result']  = enum_ret.OK
        #retMsg['message'] = 'token check ok!'
        #return retMsg
        #End

        #Check task arguments
        if args_dict['task_type'] == task_type.POWERON or args_dict['task_type'] == task_type.POWERSTATUS or args_dict['task_type'] == task_type.POWEROFF:
            must_keys = {'idc_id':'', 'task_type':''}
        else:
            must_keys = {'task_uuid':'', 'idc_id':'', 'task_type':''}

        chk_ret = self._args_check_ok(must_keys, args_dict)
        if chk_ret[0] is False:
           DEBUG and debug_print(chk_ret[1])
           return chk_ret[1]

        #Create cluster
        if args_dict['task_type'] == task_type.CREATE: 
	   chk_ret = self._args_check_ok(pattern_dict.CREATE, args_dict)
	   if chk_ret[0] is False:
              DEBUG and debug_print(chk_ret[1])
	      return chk_ret[1]

           if not args_dict['cluster_type'] in [cluster_type.VMWARE, cluster_type.XENSERVER]:
              retMsg['result']  = enum_ret.ERROR
              retMsg['message'] = ret_msg.INVALID_CLUSTER_TYPE
              DEBUG and debug_print(retMsg)
              return retMsg

        #Add server
        elif args_dict['task_type'] == task_type.ADD:
            chk_ret = self._args_check_ok(pattern_dict.UPDATE, args_dict)
	    if chk_ret[0] is False:
               DEBUG and debug_print(chk_ret[1])
	       return chk_ret[1]

        #Delete cluster
        elif args_dict['task_type'] == task_type.DELETE: 
            chk_ret = self._args_check_ok(pattern_dict.DELETE, args_dict)
	    if chk_ret[0] is False:
               DEBUG and debug_print(chk_ret[1])
	       return chk_ret[1]

        #Power up server
        elif args_dict['task_type'] == task_type.POWERON: 
            chk_ret = self._args_check_ok(pattern_dict.POWERON, args_dict)
	    if chk_ret[0] is False:
               DEBUG and debug_print(chk_ret[1])
	       return chk_ret[1]

        #Get power status 
        elif args_dict['task_type'] == task_type.POWERSTATUS: 
            chk_ret = self._args_check_ok(pattern_dict.POWERSTATUS, args_dict)
	    if chk_ret[0] is False:
               DEBUG and debug_print(chk_ret[1])
	       return chk_ret[1]
      
        #Power down server
        elif args_dict['task_type'] == task_type.POWEROFF: 
            chk_ret = self._args_check_ok(pattern_dict.POWEROFF, args_dict)
	    if chk_ret[0] is False:
               DEBUG and debug_print(chk_ret[1])
	       return chk_ret[1]

        else:            	
            retMsg['result']  = enum_ret.ERROR
	    retMsg['message'] = ret_msg.INVALID_TASK_TYPE+': ' + args_dict['task_type']
            DEBUG and debug_print(retMsg)
            return retMsg
       
        #Synchronously calling for power status management 
        if args_dict['task_type'] == task_type.POWERON or args_dict['task_type'] == task_type.POWERSTATUS or args_dict['task_type'] == task_type.POWEROFF:

           print 'power status-----------------'
           condition = {}
           condition['idc_id'] = args_dict['idc_id']

           factoryDB = FactoryDBConnect()
           idcs, idc_num  = factoryDB.queryTable(table_name.CF_AGENT, '')

           if idc_num < 0:
	      print 'No registration info for IDC: %s' % args_dict['idc_id']
              retMsg['result']  = enum_ret.ERROR
	      retMsg['message'] = ret_msg.INVALID_IDC_INFO

              return retMsg

           xmlrpcObj = xmlrpclib.ServerProxy(idcs[0]['req_url'], allow_none=True) 
         
           result = xmlrpcObj.request(args_dict)

           retMsg['result']  = enum_ret.OK
           retMsg['return']  = result['return']

           return retMsg
        
        #Asynchronously processing tasks
        else:
           self.task_list.append(args_dict)

           retMsg['result']  = enum_ret.OK
           retMsg['message'] = 'Request success!'

           return retMsg 

    @classmethod 
    def update_task_status(cls, task_uuid, status, ret_dict={}, comment=''):
	
        DEBUG and debug_print('\nTask: %s, status: %s\n' % (task_uuid, status, ) )

        retMsg            = {}
        retMsg['return']  = ''
        retMsg['message'] = ''

	update_info = {}
	update_info['status']  = status
	update_info['comment'] = comment

	condition = {}
	condition['task_uuid'] = task_uuid
	
	try:
	   factoryDB = FactoryDBConnect()
	   factoryDB.update_record(update_info, condition, table_name.CF_TASK)

           condition = {}
	   condition['task_uuid'] = task_uuid
   
           tasks, task_num = factoryDB.queryTable(table_name.CF_TASK, condition)


           if task_num > 0:
              if tasks[0]['task_type'] != task_type.DELETE:
  	         if status == task_status.SUCCESS or status == task_status.FAILED or status == task_status.REQ_ERROR:
                     s=xmlrpclib.ServerProxy(hpc_mgr.REQ_URL)
              
                     DEBUG and debug_print('Send cluster info to HPC Manager:')
                     DEBUG and debug_print(ret_dict)
                   
                     time.sleep(60) 
                     s.afterCreateCloudFactory(ret_dict)
#                      cbThread = Thread(target=call_hpcmgr_back, kwargs=ret_dict)
#                      cbThread.daemon = True
#                      cbThread.start()

           retMsg['result'] = enum_ret.OK
           return retMsg 

	except Exception, e:
           print_except_line()
           retMsg['result'] = enum_ret.ERROR
           return retMsg 

    @classmethod
    def signal_handler(cls, signum, frame):

	DEBUG and debug_print('In custom signal handler for SIGTERM')
	
	if signum == signal.SIGTERM:
	   tasks, task_num = factoryDB.queryTable(table_name.CF_TASK, '')
	   for task in tasks:
	       if task['status'] != task_status.SUCCESS:
		  cls.update_task_status(task['task_uuid'], task_status.FAILED) 
 
    @classmethod 
    def task_process(cls):
        
        while True:
              while len(cls.task_list) != 0:
                    task_info = cls.task_list.pop(0)

                    cf_task  = {}
                    key_list = ['task_uuid', 'idc_id', 'cluster_id', 
                                'cluster_type', 'cluster_name', 'task_type']

                    for k in key_list:
                        if k in task_info.keys():
                           cf_task[k] = str(task_info[k])

                    cf_task['status'] = task_status.INITIAL
                    
                    try: 
		       factoryDB = FactoryDBConnect()
                       print '\n' 
                       #print cf_task 
                       result = factoryDB.insert_record(cf_task, table_name.CF_TASK)
		       
        	       if not result[0]:
                          print ADD_TASK_ERR 
                          continue
      
                       condition = {}
                       condition['idc_id'] = task_info['idc_id']

                       idcs, idc_num  = factoryDB.queryTable(table_name.CF_AGENT, '')

		       if idc_num < 0:
		 	  print 'No registration info for IDC: %s' % task_info['idc_id']
			  continue

		       xmlrpcObj = xmlrpclib.ServerProxy(idcs[0]['req_url'], allow_none=True) 
         
                       result = xmlrpcObj.request(task_info)
  
                       if result['result'] != '0':
                          print  result['message']
                          cls.update_task_status(task_info['task_uuid'], task_status.REQ_ERROR) 
                       else: 
                          cls.update_task_status(task_info['task_uuid'], task_status.PROGRESS)

                    except Exception, e:
                       print_except_line()
                       print e

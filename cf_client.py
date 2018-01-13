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
import uuid
import json
import hashlib
import hmac
import sha

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
    security_string = "<"+str(timestamp)+"><"+ "request"+">"
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

xmlrpcObj = xmlrpclib.ServerProxy('http://10.86.11.161:8000/cloudfactory', allow_none=True)

stoken=genStoken('86B41641-6567-4131-B14A-52C606C4FF16', 'F426C0F2-0368-4AF5-B69C-9F5EE6799E79', 'request')
#time.sleep(130)
args_poweron={'task_uuid':'20150113101155674212', 'idc_id':'00012', 'macaddress':'bc:30:5b:da:60:66', 'task_type':'poweron'}

args_powerstatus={'task_uuid':'20150113101155674212', 'idc_id':'00012', 'macaddress':'bc:30:5b:da:60:66', 'task_type':'powerstatus'}

args_poweroff={'task_uuid':'20150113101155674212', 'idc_id':'00012', 'macaddress':'bc:30:5b:da:60:66', 'task_type':'poweroff'}

ret=xmlrpcObj.request(stoken, args_powerstatus)

print ret


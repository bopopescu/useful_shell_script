'''
Created on 2015-06-24

@author: Wei shun
'''

import os
import sys
import csv
import time
import uuid
import random
import base64
import syslog
import traceback
import threading
import xmlrpclib
import subprocess
import ConfigParser
from SimpleXMLRPCServer import SimpleXMLRPCServer,SimpleXMLRPCRequestHandler

def except_line_info():

    for frame in traceback.extract_tb(sys.exc_info()[2]):
	fname,lineno,fn,text = frame
	except_string = "Error in %s, line: %d in func: %s"%(fname,lineno,fn,)
	return except_string


def createMac():
   Maclist = []
   for i in range(1,6):
      RANDSTR = "".join(random.sample("0123456789abcdef",2))
      Maclist.append(RANDSTR)
   RANDMAC = ":".join(Maclist)
   return "00:%s"%RANDMAC


def randomStringPwd(b):
    c = b - 1
    p = random.randint(1,c)
    q = random.randint(1,c-p)
    o = b - p - q
    y = "ABCDEFGHIGKLMNOPQRSTUVWXYZ"
    x = "abcdefghigklmnopqrstuvwxyz"
    a = "1234567890"
    e = ""
    for n in range(0,p):
        m = random.randint(0,len(y)-1)
        e="%s%s"%(e,y[m])
    f = ""
    for n in range(0,q):
        m = random.randint(0,len(x)-1)
        f="%s%s"%(f,x[m])    
    g = ""
    for n in range(0,o):
        m = random.randint(0,len(a)-1)
        g="%s%s"%(g,a[m])

    h = "%s%s%s" % (e, f, g)
    k = ""
    for n in range(0,b):
        m = random.randint(0,len(h)-1)
        k="%s%s"%(k,h[m])
    return k

#Restrict to a particular path.
class RequestHandler(SimpleXMLRPCRequestHandler):
  rpc_paths = ('/RPC2',)
  

class Scheduler:
  
  def __init__(self):

      self.host_ip     = ''     
      self.vm_list     = []
      self.host_list   = []
      self.host_filter = Filter.create()


  def get_hosts_info(self, fname):

      with open(fname, 'rb') as f:

         reader = csv.reader(f)

         try:
             for row in reader:
                 dict = {}
                 for kv in row:
                     
                     k, v = kv.split(':')
                     dict[k] = v

                 self.host_list.append(dict)   
 
         except Exception as e:

             print 'file %s, line %d: %s' % (fname, reader.line_num, e)


  def get_vms_info(self, fname):

      with open(fname, 'rb') as f:

         reader = csv.reader(f)

         try:
             for row in reader:
                 dict = {}
                 for kv in row:
                     k, v = kv.split(':')
                     dict[k] = v

                 self.vm_list.append(dict)    

         except csv.Error as e:

             print 'file %s, line %d: %s' % (fname, reader.line_num, e)


  def update_hosts_resource(self, fname):
     
      file_content = []
 
      for host in self.host_list:
          row = []
          for key in host.keys():
              row.append(str(key) + ':' + str(host[key]))  

          file_content.append(row) 

      file_tmp = fname + '.tmp'

      with open(file_tmp, 'wb') as f:

	  writer = csv.writer(f)

	  try:

              for row in file_content:
	          writer.writerow(row) 
 
	      ret = os.system('rm -f ' + fname)
	      if ret:
		 print 'Failed to remove old file: %s' % fname

	      ret = os.system('mv ' + file_tmp +' '+ fname)
	      if ret:
		 print 'Failed to rename file: %s' % fname
	     
	  except csv.Error as e:

	      print 'file %s, line %d: %s' % (file_tmp, writer.line_num, e)

                       
  def update_vms_property(self, fname):
      
      file_content = []

      for vm in self.vm_list:
          row = []
          for key in vm.keys():
              row.append(str(key) + ':' + str(vm[key]))   

          file_content.append(row) 
 
      file_tmp = fname + '.tmp' 

      with open(file_tmp, 'wb') as f:

	  writer = csv.writer(f)

	  try:
              for row in file_content:
                  writer.writerow(row)

	      ret = os.system('rm -f ' + fname)
	      if ret:
		 print 'Failed to remove old file: %s' % fname

	      ret = os.system('mv ' + file_tmp +' '+ fname)
	      if ret:
		 print 'Failed to rename file: %s' % fname
	      
	  except csv.Error as e:

	      print 'file %s, line %d: %s' % (file_tmp, writer.line_num, e)


  def add_hosts(self, host_list):
      pass


  def del_hosts(self, host_list):
      pass


  def del_vms(self, vm_list):
      pass


  def produce_deploy_csv(self, vm_specs, fname):
     
      file_content = []
       
      for vm_spec in vm_specs:
          row = []
#          for key in vm_spec.keys():
#              if key == 'excludeprovisiontag' or key == 'bizonetag' or key == 'apptype':
#                 continue
#              row.append(key + ':' + vm_spec[key])
  
          row.append(vm_spec['vmname'])
          row.append(vm_spec['tplname'])
          row.append(vm_spec['sruuid'])
          row.append(vm_spec['cpu'])
          row.append(vm_spec['disk']+'GiB')
          row.append(vm_spec['mem']+'GiB')
          row.append(vm_spec['mem']+'GiB')
          row.append(vm_spec['mem']+'GiB')
          row.append(vm_spec['mem']+'GiB')
          #row.append(vm_spec['static_min_ram'])
          #row.append(vm_spec['dync_min_ram'])
          #row.append(vm_spec['dync_max_ram'])
          #row.append(vm_spec['static_max_ram'])
          row.append(str(int(vm_spec['qos'])*1024))
          #row.append(vm_spec['eth0_mac'])
          row.append(createMac())
          row.append(vm_spec['eth0_network'])
          #row.append(vm_spec['eth1_mac'])
          row.append(createMac())
          row.append(vm_spec['eth1_network'])
          #row.append(vm_spec['eth2_mac'])
          row.append('00:00:00:00:00:00')
          row.append('1')
          row.append('00:00:00:00:00:00')
          row.append('1')
          #row.append(vm_spec['eth3_mac'])
          #row.append(vm_spec['host'])

          file_content.append(row)
               
      with open(fname, 'wb') as f:

	  writer = csv.writer(f)

	  try:
              for row in file_content:
	          writer.writerow(row)

	  except csv.Error as e:

	      print 'file %s, line %d: %s' % (file_tmp, writer.line_num, e)


  def schedule_instances(self, vm_specs, host_csv='host.csv', vm_csv='vm.csv'):

      import operator

      for vm_spec in vm_specs:
     
	  hosts_chosen = self.host_filter.filter_hosts(self.host_list, vm_spec)
	  hosts_weight = WeightCalc.get_hosts_weight(hosts_chosen)

          host_appropriate = False

          #Sort descending
          hosts_weight.sort(key=operator.itemgetter('weight'), reverse=True)

          for h_w in hosts_weight:

              if (int(h_w['host']['cpu_max'])-int(h_w['host']['cpu_used']))<int(vm_spec['cpu']):
                 continue
              if (int(h_w['host']['mem_max'])-int(h_w['host']['mem_used']))<int(vm_spec['mem']):
                 continue

              host_appropriate = True

              vm_spec['host']   = h_w['host']['uuid']
              vm_spec['sruuid'] = h_w['host']['sruuid']
              vm_spec['eth0_network'] = h_w['host']['eth0_network']
              vm_spec['eth1_network'] = h_w['host']['eth1_network']
             
              #Update host resource
              for host in self.host_list:

                  if host['uuid'] == vm_spec['host']:
                     host['cpu_used']  = str(int(host['cpu_used'])+int(vm_spec['cpu']))
                     host['mem_used']  = str(int(host['mem_used'])+int(vm_spec['mem']))
                     host['disk_used'] = str(int(host['disk_used'])+int(vm_spec['disk']))

                     vm_exclude_tags   = vm_spec['excludeprovisiontag'].split(';')

                     for exclude_tag in vm_exclude_tags:

                         if exclude_tag not in host['excludeprovisiontag'].split(';'):

			     if host['excludeprovisiontag'] == '':
				host['excludeprovisiontag'] += exclude_tag
			     else:
				host['excludeprovisiontag'] += ';' + exclude_tag

                     break
              
              break

          if not host_appropriate:
             print 'No host meets requirement of VM:%s, CPU:%s, MEM:%s'%\
                       (vm_spec['vmname'], vm_spec['cpu'], vm_spec['mem'])


      self.update_vms_property(vm_csv) 
      self.update_hosts_resource(host_csv)

      self.produce_deploy_csv(vm_specs, 'provision.csv')


class Filter:
  
  def __init__(self):
      pass


  @classmethod
  def create(cls):
     
     return cls()


  def filter_hosts(self, host_list, vm_spec):

      hosts_available = []

      for host in host_list:
          host_tags = host['excludeprovisiontag'].split(';')
          vm_tags   = vm_spec['excludeprovisiontag'].split(';')

          for h_t in host_tags:
              if h_t == '':
                 host_tags.remove(h_t) 

          for v_t in vm_tags:
              if v_t == '':
                 vm_tags.remove(v_t) 

          bIncluded = False

          for vm_tag in vm_tags:
              if vm_tag != 'white' and vm_tag in host_tags:
                 bIncluded = True
                 break
          
          if not bIncluded:
             hosts_available.append(host) 

      return hosts_available


class WeightCalc:
  
  def __init__(self):
      pass

  @classmethod
  def get_hosts_weight(cls, host_specs, app_type=''):

      cpu_intensive_factors = {'cpu': 0.6, 'mem':0.4} 
      mem_intensive_factors = {'cpu': 0.4, 'mem':0.6} 
      io_intensive_factors  = {'cpu': 0.5, 'mem':0.5} 

      factors = {}

      if app_type == 'cpu':
         factors = cpu_intensive_factors
      elif app_type == 'mem': 
         factors = mem_intensive_factors
      elif app_type == 'io': 
         factors = io_intensive_factors
      else:
         factors = io_intensive_factors

      hosts_weight = []

      for host in host_specs:
          hosts_weight.append({'host': host,
                               'weight': (int(host['cpu_max'])-int(host['cpu_used']))*factors['cpu'] \
                                        +(int(host['mem_max'])-int(host['mem_used']))*factors['mem']})

      return hosts_weight 



if __name__ == '__main__':

   scheduler = Scheduler()
  
   scheduler.get_hosts_info('host.csv') 
   scheduler.get_vms_info('vm.csv') 

   scheduler.schedule_instances(scheduler.vm_list)


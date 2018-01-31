# -*- coding: utf-8 -*-

from twisted.internet import reactor, threads
from twisted.python import threadable
from twisted.web import server, resource, xmlrpc
import time
import sys
import xmlrpclib
import subprocess
import signal
from threading import Thread
from datetime import datetime
from factoryDB import FactoryDBConnect
from CFServerMgr import *

class RootResource(resource.Resource):
    
    def __init__(self):
        resource.Resource.__init__(self)                    
    
    def render_GET(self,request):
        return "Bad Request"
    
    def render_POST(self,request):
        request.setHeader("content-type", ["text/html"])
        request.write("Bad Request")
        request.finish()    
    
    def getChild(self,path,request):
        print "Bad Request"
  
def getCurrentTime():
    
    currentTime = long(time.time()*1000)
    res = {"result":0, "return":str(currentTime),"message":"Running"}
    return res

class Result(object):
    def __init__(self,data,result=0,msg="done"):
        self.result = result
        self.message = msg
        setattr(self,"return",data)
        
    @property    
    def success(self):
        return self.result == 0
       
    @property    
    def content(self):
        return getattr(self,"return",0)
    
    @content.setter    
    def content(self,new_value):
        setattr(self,"return",new_value)

    def __getitem__(self, key):
        if "result" ==key:
            return self.result
        elif "return" ==key:
            return getattr(self,"return",0)
        elif "message" ==key:
            return self.message
        else:
            return None
        
    def __str__(self):
        return "Result<'result':%d,'message':'%s','return':%s>"%(self.result,self.message,str(self.content))
    
    def to_msg_result(self):
        return {"Success":self.result==0,"KernelMessage":self.content,"Describe":self.message}


def packageResult(func):
    def wappedFun(*args,**kwargs):
        try:
            result = func(*args,**kwargs)
            #result = Result(result)
        except Exception,ex:
            print_except_line()
            print ex
        return result
    return wappedFun


class AdminRPCHandler(xmlrpc.XMLRPC):
    '''
     all request will call to render_POST
    '''
    def __init__(self,allow_none = True,useDateTime=False, encoding = "UTF-8"):
        
        xmlrpc.XMLRPC.__init__(self,allow_none, useDateTime)
        self.isLeaf = True
        self.encoding = encoding
        self.moduls = {}
        self.initModul()
        
    def initModul(self):
        
        self.moduls["cf_server"] = CFServerMgr.instance()
    
    def render_POST(self, request):
        '''
        all request have to verify permission first. 
        all request first three args is timestamp,access_uuid,security_hash to verify permission
        '''
        request.content.seek(0, 0)
        request.setHeader("content-type", "text/xml")
        
        try:
            if self.useDateTime:
               args, functionName = xmlrpclib.loads(request.content.read(),use_datetime=True)
            else:                
               args, functionName = xmlrpclib.loads(request.content.read()) 
            #ip = request.getClientIP()

            #if functionName != 'register' and functionName != 'request':
            #   raise Exception('The specified method:%s does not exist' % (functionName,) )
        
        except Exception, e:
            print_except_line()
            msg=("deserialize input error [%s]" %str(e))
            print msg
            f = xmlrpclib.Fault(self.FAILURE, "Can't deserialize input: %s" % (e))
            self._cbRender(f, request)
        
        else:
            instance_name = "cloudfactory"
            modul_name = "cf_server"
            instance = self.moduls.get(modul_name)
            if not instance:
                msg = "modul id not exists args [%s]" %str(args)
                print msg
                function = None
            else:
                function = getattr(instance, functionName, None)
                if function is None:
                    f = xmlrpclib.Fault(self.FAILURE, "The Resource didn't implement the %s method" %functionName)
                    self._cbRender(f, request)
                else:
                    function = packageResult(function)
                    responseFailed = []
                    request.notifyFinish().addErrback(responseFailed.append)
                   
                    d =  threads.deferToThread(function,*args)
                    d.addErrback(self._ebRender)
                    d.addCallback(self._cbRender, request, responseFailed)
        return server.NOT_DONE_YET 
    
def initResource():
    
    _resource = RootResource()
    _resource.putChild("cloudfactory", AdminRPCHandler())
    return _resource
    
if __name__ == '__main__':

    tpthread        = Thread(target=CFServerMgr.task_process)
    tpthread.daemon = True
    tpthread.start()  

    signal.signal(signal.SIGTERM, CFServerMgr.signal_handler) 
 
    threadable.init(1)
    reactor.suggestThreadPoolSize(10000) 
    resource = initResource()
    reactor.listenTCP(int(8000), server.Site(resource)) 

    msg = "******Cloudfactory server start up at %s******"  % (datetime.today().strftime("%Y-%m-%d %H:%M:%S"), )
    print msg
    
    reactor.run()

#!/usr/bin/python

import MySQLdb
from config import dbconfig
import string

class FactoryDBConnect():
   def __init__(self):
      '''
      '''
      self.cursor = None
      self.cursor_ret = None
      self.connection = None

   def connectDB(self):
      '''
      ''' 
      
      try:
          
          connection = MySQLdb.connect(user=dbconfig.get("user"),passwd=dbconfig.get("password"),
                                       host=dbconfig.get("host"),db=dbconfig.get("db"),
                                       charset=dbconfig.get("charset"))
          return connection

      except Exception, e:
          print "Could not connect to MySQL server:",e
   
   
   def queryTable(self,table,query_dict=''):
      '''
      ''' 
   
      _sql = 'select * from ' + table
      try:
          connection = self.connectDB()
          cursor = connection.cursor(cursorclass = MySQLdb.cursors.DictCursor)
          #_sql = 'select * from ' + table
          if query_dict != '':
              firstconditon = query_dict.popitem()
              _sql = _sql + " where " + firstconditon[0] + "='" + firstconditon[1] + "'"
              for i in query_dict.items():
                  _sql += " and " + i[0] + "='" + i[1] +"'"
          #print _sql
          cursor.execute(_sql)
          cursor_ret = cursor.fetchall()
          cursor_num = cursor.rowcount
          #result = []
          return cursor_ret,cursor_num
      except Exception, e:
          print _sql
          print e
      finally:
          #connection.commit()
          cursor.close()
          connection.close()
   

   def insert_record(self,task,table):
        '''

        '''
        try:
             connection = self.connectDB()
             cursor = connection.cursor()
             firstcol = task.popitem()
             col = ""
             val = ""
             for i in task.items():
                 col = col + ',' + i[0]
                 val = val + ",'" + i[1] + "'"
             _sql = "insert into " + table + "(" + firstcol[0] + col + ") values('" + firstcol[1] + "'" + val + ")"
             print _sql
             result = cursor.execute(_sql)
             return (result, connection.insert_id())
        except Exception, e:
             print e
        finally:
             connection.commit()
             cursor.close()
             connection.close()

   def update_record(self,update_info,condition,table):
       '''


       '''
       try:
             connection = self.connectDB()
             cursor = connection.cursor(cursorclass = MySQLdb.cursors.DictCursor)
             _sql = "update " + table + " set "
             firstcol = update_info.popitem()
             _sql = _sql + firstcol[0] + "='" + firstcol[1] + "'"
             for i in update_info.items():
                 _sql += "," + i[0] + "='" +i[1] + "'"
             
             firstcondition = condition.popitem()
             _sql = _sql + " where " + firstcondition[0] + "='" + firstcondition[1] + "'"
             for i in condition.items():
                 _sql += " and " + i[0] + "='" + i[1] + "'"
             
             result = cursor.execute(_sql)
             return result
       except Exception, e:
             print e
       finally:
             connection.commit()
             cursor.close()
             connection.close()
   
   def delete_record(self,condition,table):
       '''


       '''
       try:
             connection = self.connectDB()
             cursor = connection.cursor(cursorclass = MySQLdb.cursors.DictCursor)
             _sql = "delete from " + table + " where "
             
             firstcondition = condition.popitem()
             _sql = _sql  + firstcondition[0] + "='" + firstcondition[1] + "'"
             print _sql
             for i in condition.items():
                 _sql += " and " + i[0] + "='" + i[1] + "'"
             
             result = cursor.execute(_sql)
             return result
       except Exception, e:
             print e
       finally:
             connection.commit()
             cursor.close()
             connection.close()


   def truncateDB(self,tblName):
      ''' 
      '''
      n = 0
      try:
         self.connection = self.connectDB()
         self.cursor = self.connection.cursor()

         _sql = "TRUNCATE TABLE "+tblName

         print _sql

         n = self.cursor.execute(_sql)
         print n
      except Exception, e:
         print e
      finally:
         self.connection.commit()
         self.cursor.close()
         self.connection.close()
      return n


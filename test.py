import os
import sys
import time
import SWMgr

if __name__ == '__main__':
   
     swconn = SWMgr.SWConnector("10.86.10.131", 
                                "admin", 
                                "powerall")
  
     swconn.connect()

     intf_state = swconn.get_interface_state(10)

        
     if intf_state == SWMgr.STATE_UP:
	
        print "Interface is UP, we will shut it down"
	swconn.set_interface_state(10, SWMgr.STATE_DOWN)
         
     elif intf_state == SWMgr.STATE_DOWN:
      
        print "Interface is DOWN, we will start it up"
        swconn.set_interface_state(10, SWMgr.STATE_UP)
        
     elif intf_state == SWMgr.STATE_UNKNOWN:
             
        print "Interface is in unknown state"
        
     else:
           
        print "Interface is in unknown state"

     swconn.disconnect() 


import telnetlib

STATE_UP = 0
STATE_DOWN = 1
STATE_UNKNOWN = 2

state_desc = ["UP", "DOWN", "UNKNOWN"]

class SWConnector:

      def __init__(self, host, user, password):
 
          self.host     = host
          self.user     = user
          self.password = password

      def connect(self):
 
          self.tn = telnetlib.Telnet(self.host)
          self.tn.read_until("Username: ", 1)
          self.tn.write(self.user+"\n")

          self.tn.read_until("Password: ", 1)
          self.tn.write(self.password+"\n")

          self.tn.write("sys\n")

      def disconnect(self):
 
          if self.tn is not None:
             self.tn.write("quit\n")
             self.tn.write("quit\n")
             self.tn.close()
    
      def get_interface_state(self, intf):
         
          if self.tn is None:
             return STATE_UNKNOWN
 
          if intf < 0 or intf > 24:
             return STATE_UNKNOWN

          self.tn.write("display interface GigabitEthernet 0/0/%d\n" % (intf, ) )
          self.tn.read_until("Line protocol current state :", 3)
          readStr=self.tn.read_until("Description", 3)
          self.tn.write("q\n")

          if "UP" in readStr:
              return STATE_UP
          elif "DOWN" in readStr:
              return STATE_DOWN
          else:
              return STATE_UNKNOWN
   
      def set_interface_state(self, intf, state):

          if self.tn is None:
             return False

          if intf < 0 or intf > 23:
             return False

          setcmd = ""
          
          if state == STATE_UP:
             setcmd = "restart\n"
          elif state == STATE_DOWN:
             setcmd = "shutdown\n"
          else:
             return False

          self.tn.write("interface GigabitEthernet 0/0/%d\n" % (intf, ) )
          self.tn.write(setcmd)
          self.tn.write("display this\n")
          readStr=self.tn.read_until("link-type", 1)
          self.tn.write("quit\n")

          return True

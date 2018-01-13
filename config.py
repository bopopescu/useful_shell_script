dbconfig = {
        "host":"localhost",
        "user":"root",
        "password":"powerall",
        "db":"IDC_Info",
        "charset":"utf8"
}

install_network_config = {
        "prefix" :"192.168.10.",
        "netmask":"255.255.255.0",
        "tftp_ip":"192.168.10.100"
}

class server_level:
      XENSERVER_MASTER = 'master'
      XENSERVER_SLAVE  = 'slave'
      VSPHERE_MASTER   = 'master'
      VSPHERE_SLAVE    = 'slave'

class server_status:
      INITIAL   = 'initial'
      PROGRESS  = 'progress'
      INSTALLED = 'installed'
      FAILED    = 'failed'
      DELETED   = 'deleted'
      POWERON   = 'poweron'
      POWERSTATUS='powerstatus'
      POWEROFF  = 'poweroff'

class task_status:
      INITIAL   = 'initial'
      PROGRESS  = 'progress'
      SUCCESS   = 'success'
      FAILED    = 'failed'

class table_name:
      HPC_TASK  = 'hpc_task'
      HPC_SERVER= 'hpc_server'
      HPC_VLAN  = 'hpc_vlan'

class cluster_type:
      XENSERVER = 'XenServer'
      VSPHERE   = 'VMWare'
      CCP       = 'CCP'

class task_type:
      CREATE    = 'create'
      ADD       = 'add'
      DELETE    = 'delete'
      POWERON   = 'poweron'
      POWERSTATUS='powerstatus'
      POWEROFF  = 'poweroff'

class dhcp_config:
      ADD       = 'add'
      DELETE    = 'delete'

class enum_ret:
      OK        = '0'
      ERROR     = '1'

class err_msg:
      INVALID_TASK_ID                 = 'Invalid task id'
      INVALID_TASK_TYPE               = 'Invalid task type'
      INVALID_ARGUMENT_FORMAT         = 'Invalid argument format'
      NO_SUBNET_AVAILABLE             = 'No subnet to use'
      SERVER_NOT_EXISTED              = 'The specified server does not exist'
      ADD_SERVER_TO_DB_ERR            = 'Failed to insert server info into db'
      ADD_TASK_ERR                    = 'Failed to insert new task into db'
      CLUSTER_NOT_EXIST               = 'The specified cluster id does not exist'
      ADD_SERVER_TO_CLUSTER_FAILED    = 'Failed to add server to cluster'
      REQUIRED_ARGUMENT_ABSENT        = 'No value provided for key: '

class action_type:
      ADD    = 'add'
      DELETE = 'delete'

class power_state:
      START    = 'start'
      SHUTDOWN = 'shutdown'
      POWERON  = 'poweron'
      POWERSTATUS='powerstatus'
      POWEROFF = 'poweroff'

class cf_server:
      REQ_URL  = 'http://10.86.11.161:8000/cloudfactory'

class cf_agent:
      IDC_ID      = '00012'
      REQ_URL     = 'http://192.168.21.100:8080/cloudfactory'
      ADMIN_EMAIL = 'weishun@powerallnetworks.com'

class pattern_dict:
              CREATE = {
			'task_uuid'   : '',
			'task_type'   : '',
			'idc_id'      : '',
			'cluster_id'  : '',
			'cluster_name': '',
			'cluster_type': '',
			'dns'         : '',
			'server_list' : [
					 {
					  'idrac_ip'      : '',
					  'idrac_user'    : '',
					  'idrac_password': '',
					  'macaddress'    : '',
					  'server_level'  : '',
					  'name'          : '',
					  'uuid'          : ''
					 }
					],

			'mgr_vlan'    : {
					 'vlan_no': '',
					 'ip'     : '',
					 'range'  : [],
					 'netmask': '',
					 'gateway': ''
				        },

                        'storageinfo' : {
                                         'san_ip'       : '',
                                         'san_target'   : '',
                                         'san_user'     : '',
                                         'san_password' : ''
                                        }

	               }

              ADD =    {
			'task_uuid'   : '',
			'task_type'   : '',
                        'idc_id'      : '',
			'cluster_id'  : '',
			'server_list' : [
					 {
					  'idrac_ip'      : '',
					  'idrac_user'    : '',
					  'idrac_password': '',
					  'macaddress'    : '',
					  'server_level'  : '',
					  'name'          : '',
					  'uuid'          : ''
					 }
					],
		       }

              DELETE = {
                        'task_uuid' : '',
			'task_type' : '',
                        'idc_id'    : '',
                        'cluster_id': '',
			'server_list' : [
                                         {
                                          'macaddress': ''
                                         }
                                        ]
                       }

              POWERON ={
                #        'task_uuid' : '',
                        'task_type' : '',
                        'macaddress': ''
                       }

              POWERSTATUS  = {
                            #  'task_uuid' : '',
                              'task_type' : '',
                              'macaddress': ''
                             }

              POWEROFF={
                     #   'task_uuid' : '',
                        'task_type' : '',
                        'macaddress': ''
                       }
TASK_TIMEOUT = 2400

DEBUG = True

def debug_print(info):  
    print info  


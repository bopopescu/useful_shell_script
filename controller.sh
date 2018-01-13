#!/bin/bash

sed -i "/openstack/d" /etc/rc.local

# For testing
mgr_ip="10.86.11.171"

#source common.inc

echo "controller" > /etc/hostname

ADMIN_TOKEN=`openssl rand -hex 10`
ADMIN_TOKEN="fdasfsafdafdadfsafdsa"

echo $ADMIN_TOKEN > token.txt

touch admin-openrc.sh

cat >> admin-openrc.sh << EOF
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0
export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://controller:35357/v2.0
EOF

touch demo-openrc.sh

cat >> demo-openrc.sh << EOF
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0
export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://controller:5000/v2.0
EOF

source admin-openrc.sh

# Disable automatic update services
sed -i "/APT::Periodic::Update-Package-Lists/d" /etc/apt/apt.conf.d/10periodic
sed -i '$ a APT::Periodic::Update-Package-Lists "0";' /etc/apt/apt.conf.d/10periodic

route add default gw 10.86.10.1

cd /etc/apt

mv sources.list sources.list.old
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/sources.list
cd -

apt-get -y update

# Enable the OpenStack repository
apt-get -y install ubuntu-cloud-keyring
echo "deb http://10.86.11.161/ccp/ubuntu-cloud/ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list

apt-get -y update
apt-get -y dist-upgrade

# Installing NTP service 
apt-get -y install ntp
if [ ! $? -eq 0 ]
then
   echo "Install ntp failed: $?"
else
   echo "Install ntp: OK"
fi

rm -f /etc/ntp.conf 

cd /etc

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/controller-ntp.conf
if [ ! $? -eq 0 ]
then
   echo "wget controller-ntp.conf failed: $?"
else
   echo "Get controller-ntp.conf: OK"
   mv controller-ntp.conf ntp.conf
fi

cd -

service ntp restart
if [ ! $? -eq 0 ]
then
   echo "Restart ntp service failed: $?"
   exit 1
else
   echo "Restart ntp service: OK"
fi

apt-get -y install debconf
if [ ! $? -eq 0 ]
then
   echo "Install debconf failed: $?"
   exit 1
else
   echo "Install debconf: OK"
fi

export DEBIAN_FRONTEND=noninteractive

# Configure the database server
debconf-set-selections <<< "mariadb-server-5.5 mysql-server/root_password password $MYSQL_PASS"
debconf-set-selections <<< "mariadb-server-5.5 mysql-server/root_password_again password $MYSQL_PASS"
apt-get -y install mariadb-server-5.5 python-mysqldb
if [ ! $? -eq 0 ]
then
   echo "Install mysql server failed: $?"
#   exit 1
else
   echo "Install mysql server: OK"
fi

rm -f /etc/mysql/my.cnf

cd /etc/mysql

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/my.cnf

cd -

sed -i "s/bind-address = /bind-address = $mgr_ip/g" /etc/mysql/my.cnf 

service mysql restart
if [ ! $? -eq 0 ]
then
   echo "Restart mysql server failed: $?"
   exit 1
else
   echo "Restart mysql server: OK"
fi

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/change_mysql_password.sql
if [ ! $? -eq 0 ]
then
   echo "wget change_mysql_password.sql failed: $?"
   exit 1
else
   echo "Get change_mysql_password.sql: OK"
fi

sed -i "s/newpassword/$MYSQL_PASS/g" ./change_mysql_password.sql
debian_sys_pass=`cat /etc/mysql/debian.cnf |grep password|awk '{print $3}'|awk 'NR==1{print;}'`
mysql -udebian-sys-maint -p"$debian_sys_pass" < change_mysql_password.sql
if [ ! $? -eq 0 ]
then
   echo "Set password for mysql user 'root' failed: $?"
   exit 1
else
   echo "Set password for mysql user 'root': OK"
fi

#mysql_secure_installation
if [ ! $? -eq 0 ]
then
   echo "mysql_secure_installation failed: $?"
   exit 1
else
   echo "mysql_secure_installation: OK"
fi

# Configure Message server
apt-get -y install rabbitmq-server
if [ ! $? -eq 0 ]
then
   echo "Install rabbitmq-server failed: $?"
   exit 1
else
   echo "Install rabbitmq-server: OK"
fi

rabbitmqctl change_password guest $RABBIT_PASS

mkdir /etc/rabbitmq

cd /etc/rabbitmq

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/rabbitmq.config

cd -

service rabbitmq-server restart
if [ ! $? -eq 0 ]
then
   echo "Restart rabbitmq-server failed: $?"
   exit 1
else
   echo "Restart rabbitmq-server: OK"
fi

# Configure keystone
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/keystone.sql
sed -i "s/KEYSTONE_DBPASS/$KEYSTONE_DBPASS/g" keystone.sql
mysql -uroot -p$MYSQL_PASS < keystone.sql
if [ ! $? -eq 0 ]
then
   echo "Import keystone db failed: $?"
   exit 1
else
   echo "Import keystone db: OK"
fi

apt-get -y --force-yes install keystone python-keystoneclient
if [ ! $? -eq 0 ]
then
   echo "Install keystone components failed: $?"
   exit 1
else
   echo "Install keystone components: OK"
fi

rm -f /etc/keystone/keystone.conf

cd /etc/keystone

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/keystone.conf
if [ ! $? -eq 0 ]
then
   echo "wget keystone.conf failed: $?"
   exit 1
else
   echo "Get keystone.conf: OK"
   sed -i "s/admin_token=/admin_token = $ADMIN_TOKEN/g" keystone.conf
   sed -i "s/keystone:123456/keystone:$KEYSTONE_DBPASS/g" keystone.conf
fi

cd -

su -s /bin/bash -c "keystone-manage db_sync" keystone
if [ ! $? -eq 0 ]
then
   echo "Sync keystone db failed: $?"
   exit 1
else
   echo "Sync keystone db: OK"
fi

service keystone restart
if [ ! $? -eq 0 ]
then
   echo "Restart keystone service failed: $?"
   exit 1
else
   echo "Restart keystone service: OK"
fi

rm -f /var/lib/keystone/keystone.db

(crontab -l -u keystone 2>&1 | grep -q token_flush) || \
  echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' \
  >> /var/spool/cron/crontabs/keystone

sleep 3

# Create tenants, users, and roles
keystone tenant-create --name admin --description "Admin Tenant"
if [ ! $? -eq 0 ]
then
   echo "Create tenant 'admin' failed: $?"
   exit 1
else
   echo "Create tenant 'admin': OK"
fi

keystone user-create --name admin --pass $ADMIN_PASS --email $ADMIN_EMAIL_ADDRESS
if [ ! $? -eq 0 ]
then
   echo "Create user 'admin' failed: $?"
   exit 1
else
   echo "Create user 'admin': OK"
fi

keystone role-create --name admin
if [ ! $? -eq 0 ]
then
   echo "Create role 'admin' failed: $?"
   exit 1
else
   echo "Create role 'admin': OK"
fi

keystone user-role-add --user admin --tenant admin --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'admin' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'admin': OK"
fi

# Create demo tenant
keystone tenant-create --name demo --description "Demo Tenant"
if [ ! $? -eq 0 ]
then
   echo "Create tenant 'demo' failed: $?"
   exit 1
else
   echo "Create tenant 'demo': OK"
fi

keystone user-create --name demo --tenant demo --pass $DEMO_PASS --email $DEMO_EMAIL_ADDRESS
if [ ! $? -eq 0 ]
then
   echo "Create user 'demo' failed: $?"
   exit 1
else
   echo "Create user 'demo': OK"
fi

# Create Service tenant
keystone tenant-create --name service --description "Service Tenant"
if [ ! $? -eq 0 ]
then
   echo "Create tenant 'service' failed: $?"
   exit 1
else
   echo "Create tenant 'service': OK"
fi

# Identity service
keystone service-create --name keystone --type identity --description "OpenStack Identity"
if [ ! $? -eq 0 ]
then
   echo "Create service 'keystone' failed: $?"
   exit 1
else
   echo "Create service 'keystone': OK"
fi

# Create identity service endpoint
keystone endpoint-create --service-id $(keystone service-list|awk '/ identity / {print $2}') --publicurl http://controller:5000/v2.0 --internalurl http://controller:5000/v2.0 --adminurl http://controller:35357/v2.0 --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'identity' failed: $?"
   exit 1
else
   echo "Create endpoint 'identity': OK"
fi

# Configure glance component 
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/glance.sql
if [ ! $? -eq 0 ]
then
   echo "wget change_mysql_password.sql failed: $?"
   exit 1
else
   echo "Get change_mysql_password.sql: OK"
   sed -i "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" glance.sql
fi

mysql -uroot -p$MYSQL_PASS < glance.sql
if [ ! $? -eq 0 ]
then
   echo "Import glance db failed: $?"
   exit 1
else
   echo "Import glance db: OK"
fi

keystone user-create --name glance --pass $GLANCE_PASS
if [ ! $? -eq 0 ]
then
   echo "Create user 'glance' failed: $?"
   exit 1
else
   echo "Create user 'glance': OK"
fi

keystone user-role-add --user glance --tenant service --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'glance' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'glance': OK"
fi

keystone service-create --name glance --type image --description "OpenStack Image Service"
if [ ! $? -eq 0 ]
then
   echo "Create service 'glance' failed: $?"
   exit 1
else
   echo "Create service 'glance': OK"
fi

keystone endpoint-create --service-id $(keystone service-list|awk '/ image / {print $2}') --publicurl http://controller:9292 --internalurl http://controller:9292 --adminurl http://controller:9292 --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint for glance: $?"
   exit 1
else
   echo "Create endpoint for glance: OK"
fi

apt-get -y --force-yes install glance python-glanceclient
if [ ! $? -eq 0 ]
then
   echo "Install glance component failed: $?"
   exit 1
else
   echo "Install glance component: OK"
fi

rm -f /etc/glance/glance-api.conf
rm -f /etc/glance/glance-registry.conf

cd /etc/glance

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/glance-api.conf
if [ ! $? -eq 0 ]
then
   echo "wget glance-api.conf failed: $?"
   exit 1
else
   echo "Get glance-api.conf: OK"
   sed -i "s/admin_password =/admin_password = $GLANCE_PASS/g" glance-api.conf
   sed -i "s/glance:123456/glance:$GLANCE_DBPASS/g" glance-api.conf
   sed -i "s/rabbit_password = 123456/rabbit_password = $RABBIT_PASS/g" glance-api.conf
fi
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/glance-registry.conf
if [ ! $? -eq 0 ]
then
   echo "wget glance-registry.conf failed: $?"
   exit 1
else
   echo "Get glance-registry.conf: OK"
   sed -i "s/admin_password =/admin_password = $GLANCE_PASS/g" glance-registry.conf
   sed -i "s/glance:123456/glance:$GLANCE_DBPASS/g" glance-registry.conf
   sed -i "s/rabbit_password = 123456/rabbit_password = $RABBIT_PASS/g" glance-registry.conf
fi

cd -
su -s /bin/bash -c "glance-manage db_sync" glance
if [ ! $? -eq 0 ]
then
   echo "Sync glance db failed: $?"
   exit 1
else
   echo "Sync glance db: OK"
fi

service glance-registry restart
if [ ! $? -eq 0 ]
then
   echo "Restart glance-registry failed: $?"
   exit 1
else
   echo "Restart glance-registry: OK"
fi

service glance-api restart
if [ ! $? -eq 0 ]
then
   echo "Restart glance-api failed: $?"
   exit 1
else
   echo "Restart glance-api: OK"
fi

rm -f /var/lib/glance/glance.sqlite

# Configure nova
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/nova.sql
if [ ! $? -eq 0 ]
then
   echo "wget nova.sql failed: $?"
   exit 1
else
   echo "Get nova.sql: OK"
   sed -i "s/NOVA_DBPASS/$NOVA_DBPASS/g" nova.sql
fi

mysql -uroot -p$MYSQL_PASS < nova.sql
if [ ! $? -eq 0 ]
then
   echo "Import nova db failed: $?"
   exit 1
else
   echo "Import nova db: OK"
fi

keystone user-create --name nova --pass $NOVA_PASS
if [ ! $? -eq 0 ]
then
   echo "Create user 'nova' failed: $?"
   exit 1
else
   echo "Create user 'nova': OK"
fi

keystone user-role-add --user nova --tenant service --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'nova' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'nova': OK"
fi

keystone service-create --name nova --type compute --description "OpenStack Compute"
if [ ! $? -eq 0 ]
then
   echo "Create service 'nova' failed: $?"
   exit 1
else
   echo "Create service 'nova': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ compute / {print $2}') --publicurl http://controller:8774/v2/%\(tenant_id\)s --internalurl http://controller:8774/v2/%\(tenant_id\)s --adminurl http://controller:8774/v2/%\(tenant_id\)s --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'compute' failed: $?"
   exit 1
else
   echo "Create endpoint 'compute': OK"
fi

apt-get -y --force-yes install nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient
if [ ! $? -eq 0 ]
then
   echo "Install nova components failed: $?"
   exit 1
else
   echo "Install nova components: OK"
fi

rm -f /etc/nova/nova.conf

cd /etc/nova

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/nova-controller.conf
if [ ! $? -eq 0 ]
then
   echo "wget nova-controller.conf failed: $?"
else
   echo "Get nova-controller.conf: OK"
   mv nova-controller.conf nova.conf
   sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" nova.conf
   sed -i "s/admin_password =/admin_password = $NOVA_PASS/g" nova.conf
   sed -i "s/my_ip =/my_ip = $mgr_ip/g" nova.conf
   sed -i "s/nova:123456/nova:$NOVA_DBPASS/g" nova.conf
   sed -i "s/vncserver_listen =/vncserver_listen = $mgr_ip/g" nova.conf
   sed -i "s/vncserver_proxyclient_address =/vncserver_proxyclient_address = $mgr_ip/g" nova.conf
fi

cd -

su -s /bin/bash -c "nova-manage db sync" nova
if [ ! $? -eq 0 ]
then
   echo "Sync nova db failed: $?"
   exit 1
else
   echo "Sync nova db: OK"
fi

service nova-api restart && service nova-cert restart && service nova-consoleauth restart && service nova-scheduler restart && service nova-conductor restart && service nova-novncproxy restart
if [ ! $? -eq 0 ]
then
   echo "Restart nova services failed: $?"
   exit 1
else
   echo "Restart nova services: OK"
fi

rm -f /var/lib/nova/nova.sqlite

# Configure neutron component
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/neutron.sql
if [ ! $? -eq 0 ]
then
   echo "wget neutron.sql failed: $?"
   exit 1
else
   echo "Get neutron.sql: OK"
   sed -i "s/NEUTRON_DBPASS/$NEUTRON_DBPASS/g" neutron.sql
fi

mysql -uroot -p$MYSQL_PASS < neutron.sql
if [ ! $? -eq 0 ]
then
   echo "Import neutron db failed: $?"
   exit 1
else
   echo "Import neutron db: OK"
fi

keystone user-create --name neutron --pass $NEUTRON_PASS
if [ ! $? -eq 0 ]
then
   echo "Create user 'neutron' failed: $?"
   exit 1
else
   echo "Create user 'neutron': OK"
fi

keystone user-role-add --user neutron --tenant service --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'neutron' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'neutron': OK"
fi

keystone service-create --name neutron --type network --description "OpenStack Networking"
if [ ! $? -eq 0 ]
then
   echo "Create service 'neutron' failed: $?"
   exit 1
else
   echo "Create service 'neutron': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ network / {print $2}') --publicurl http://controller:9696 --adminurl http://controller:9696 --internalurl http://controller:9696 --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'neutron' failed: $?"
   exit 1
else
   echo "Create endpoint 'neutron': OK"
fi

apt-get -y --force-yes install neutron-server neutron-plugin-ml2 python-neutronclient
if [ ! $? -eq 0 ]
then
   echo "Install neutron components failed: $?"
   exit 1
else
   echo "Install neutron components: OK"
fi

rm -f /etc/neutron/neutron.conf

cd /etc/neutron

nova_admin_tenant_id=`keystone tenant-get service|grep id|awk '{print $4}'`

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/neutron-controller.conf
mv neutron-controller.conf neutron.conf
sed -i "s/^admin_password =/admin_password = $NEUTRON_PASS/g" neutron.conf
sed -i "s/nova_admin_password =/nova_admin_password = $NOVA_PASS/g" neutron.conf
sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" neutron.conf
sed -i "s/neutron:123456/neutron:$NEUTRON_DBPASS/g" neutron.conf
sed -i "s/nova_admin_tenant_id =/nova_admin_tenant_id = $nova_admin_tenant_id/g" neutron.conf

cd -

rm -f /etc/neutron/plugins/ml2/ml2_conf.ini 

cd /etc/neutron/plugins/ml2

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/controller_ml2_conf.ini
if [ ! $? -eq 0 ]
then
   echo "wget controller_ml2_conf.ini failed: $?"
   exit 1
else
   echo "Get controller_ml2_conf.ini: OK"
   mv controller_ml2_conf.ini ml2_conf.ini
fi

cd -

su -s /bin/bash -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron
if [ ! $? -eq 0 ]
then
   echo "Sync neutron db failed: $?"
#   exit 1
else
   echo "Sync neutron db: OK"
fi

service nova-api restart && service nova-scheduler restart && service nova-conductor restart
if [ ! $? -eq 0 ]
then
   echo "Restart nova services failed: $?"
   exit 1
else
   echo "Restart nova services: OK"
fi

# Configure dashboard component
apt-get -y --force-yes install openstack-dashboard apache2 libapache2-mod-wsgi memcached python-memcache
if [ ! $? -eq 0 ]
then
   echo "Install dashboard components failed: $?"
   exit 1
else
   echo "Install dashboard components: OK"
fi

rm -f /etc/openstack-dashboard/local_settings.py

cd /etc/openstack-dashboard

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/local_settings.py
if [ ! $? -eq 0 ]
then
   echo "wget local_settings.py failed: $?"
else
   echo "Get local_settings.py: OK"
fi

cd -

service apache2 restart && service memcached restart
if [ ! $? -eq 0 ]
then
   echo "Restart apache2 and memcached services failed: $?"
   exit 1
else
   echo "Restart apache2 and memcached services: OK"
fi

# Configure cinder component 
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/cinder.sql
if [ ! $? -eq 0 ]
then
   echo "wget cinder.sql failed: $?"
   exit 1
else
   echo "Get cinder.sql: OK"
   sed -i "s/CINDER_DBPASS/$CINDER_DBPASS/g" cinder.sql
fi

mysql -uroot -p$MYSQL_PASS < cinder.sql
if [ ! $? -eq 0 ]
then
   echo "Import cinder db failed: $?"
   exit 1
else
   echo "Import cinder db: OK"
fi

keystone user-create --name cinder --pass $CINDER_PASS
if [ ! $? -eq 0 ]
then
   echo "Create user 'cinder' failed: $?"
   exit 1
else
   echo "Create user 'cinder': OK"
fi

keystone user-role-add --user cinder --tenant service --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'cinder' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'cinder': OK"
fi

keystone service-create --name cinder --type volume --description "OpenStack Block Storage"
if [ ! $? -eq 0 ]
then
   echo "Create service 'cinder' failed: $?"
   exit 1
else
   echo "Create service 'cinder': OK"
fi

keystone service-create --name cinderv2 --type volumev2 --description "OpenStack Block Storage"
if [ ! $? -eq 0 ]
then
   echo "Create service 'cinderv2' failed: $?"
   exit 1
else
   echo "Create service 'cinderv2': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ volume / {print $2}') --publicurl http://controller:8776/v1/%\(tenant_id\)s --internalurl http://controller:8776/v1/%\(tenant_id\)s --adminurl http://controller:8776/v1/%\(tenant_id\)s --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'volume' failed: $?"
   exit 1
else
   echo "Create endpoint 'volume': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ volumev2 / {print $2}') --publicurl http://controller:8776/v2/%\(tenant_id\)s --internalurl http://controller:8776/v2/%\(tenant_id\)s --adminurl http://controller:8776/v2/%\(tenant_id\)s --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'volumev2' failed: $?"
   exit 1
else
   echo "Create endpoint 'volumev2': OK"
fi

apt-get -y --force-yes install cinder-api cinder-scheduler python-cinderclient
if [ ! $? -eq 0 ]
then
   echo "Install cinder components failed: $?"
   exit 1
else
   echo "Install cinder components: OK"
fi

rm -f /etc/cinder/cinder.conf

cd /etc/cinder

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/cinder-controller.conf
if [ ! $? -eq 0 ]
then
   echo "wget cinder-controller.conf failed: $?"
   exit 1
else
   echo "Get cinder-controller.conf: OK"
   mv cinder-controller.conf cinder.conf
   sed -i "s/my_ip =/my_ip =$mgr_ip/g" cinder.conf
   sed -i "s/cinder:123456/cinder:$CINDER_DBPASS/g" cinder.conf
   sed -i "s/admin_password =/admin_password = $CINDER_PASS/g" cinder.conf
   sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" cinder.conf
fi

cd -

su -s /bin/bash -c "cinder-manage db sync" cinder
if [ ! $? -eq 0 ]
then
   echo "Sync cinder db failed: $?"
   exit 1
else
   echo "Sync cinder db: OK"
fi

service cinder-scheduler restart && service cinder-api restart
if [ ! $? -eq 0 ]
then
   echo "Restart cinder services failed: $?"
   exit 1
else
   echo "Restart cinder services: OK"
fi

rm -f /var/lib/cinder/cinder.sqlite

# Configure swift component
keystone user-create --name swift --pass $SWIFT_PASS
if [ ! $? -eq 0 ]
then
   echo "Create user 'swift' failed: $?"
   exit 1
else
   echo "Create user 'swift': OK"
fi

keystone user-role-add --user swift --tenant service --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'swift' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'swift': OK"
fi

keystone service-create --name swift --type object-store --description "OpenStack Object Storage"
if [ ! $? -eq 0 ]
then
   echo "Create service 'swift' failed: $?"
   exit 1
else
   echo "Create service 'swift': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ object-store / {print $2}') --publicurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' --internalurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' --adminurl http://controller:8080 --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'object-store' failed: $?"
   exit 1
else
   echo "Create endpoint 'object-store': OK"
fi

#echo "deb http://10.86.11.161/yum_repo/images/os/openstack/ubuntu-cloud/ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list
#apt-get -y update
apt-get -y install python-keystonemiddleware
#echo "" > /etc/apt/sources.list.d/cloudarchive-juno.list

#apt-get -y update
apt-get -y --force-yes install swift swift-proxy python-swiftclient python-keystoneclient  memcached
if [ ! $? -eq 0 ]
then
   echo "Install swift components failed: $?"
   exit 1
else
   echo "Install swift components: OK"
fi

mkdir /etc/swift

cd /etc/swift

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/proxy-server.conf
if [ ! $? -eq 0 ]
then
   echo "wget proxy-server.conf failed: $?"
   exit 1
else
   echo "Get proxy-server.conf: OK"
   sed -i "s/admin_password =/admin_password = $SWIFT_PASS/g" proxy-server.conf
fi

# Account ring
swift-ring-builder account.builder create 10 3 1
if [ ! $? -eq 0 ]
then
   echo "Create Account ring failed: $?"
   exit 1
else
   echo "Create Account ring: OK"
fi

# Container ring
swift-ring-builder container.builder create 10 3 1
if [ ! $? -eq 0 ]
then
   echo "Create Container ring failed: $?"
   exit 1
else
   echo "Create Container ring: OK"
fi

# Object ring
swift-ring-builder object.builder create 10 3 1
if [ ! $? -eq 0 ]
then
   echo "Create Object ring failed: $?"
   exit 1
else
   echo "Create Object ring: OK"
fi

#cluster_id=`python getParam.py $mac '' cluster_id`
#SERVER_MAC_LIST=`python getParam.py '' $cluster_id  macaddress`

#for MAC in $(echo $SERVER_MAC_LIST|awk '{print;}')
#do
#   server_level=`python getParam.py $MAC '' server_level`
#   if [ $server_level = "swift" ]
#   then
#      MGR_IP=`python getParam.py $MAC '' mgr_ip`
 
      # Assume 'sdb' for our installation
#      swift-ring-builder account.builder add r1z1-$MGR_IP:6002/sdb 100
#      swift-ring-builder account.builder rebalance
#      swift-ring-builder container.builder add r1z1-$MGR_IP:6001/sdb 100
#      swift-ring-builder container.builder rebalance
#      swift-ring-builder object.builder add r1z1-$MGR_IP:6000/sdb 100
#      swift-ring-builder object.builder rebalance
#   fi
#done

# For testing 
swift-ring-builder account.builder add r1z1-10.86.11.175:6002/xvdb 100
swift-ring-builder account.builder rebalance
swift-ring-builder container.builder add r1z1-10.86.11.175:6001/xvdb 100
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder add r1z1-10.86.11.175:6000/xvdb 100
swift-ring-builder object.builder rebalance
# end

# Configure hashes and default storage policy
rm -f  /etc/swift/swift.conf

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/swift-controller.conf
if [ ! $? -eq 0 ]
then
   echo "wget swift-controller.conf failed: $?"
   exit 1
else
   echo "Get swift-controller: OK"
   mv swift-controller.conf swift.conf
fi

cd -

chown -R swift:swift /etc/swift

service memcached restart && service swift-proxy restart
if [ ! $? -eq 0 ]
then
   echo "Restart swift services failed: $?"
#   exit 1
else
   echo "Restart swift services: OK"
fi

# Configure Orchestration
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/heat.sql
if [ ! $? -eq 0 ]
then
   echo "wget heat.sql failed: $?"
   exit 1
else
   echo "Get heat.sql: OK"
   sed -i "s/HEAT_DBPASS/$HEAT_DBPASS/g" heat.sql
fi

mysql -uroot -p$MYSQL_PASS < heat.sql
if [ ! $? -eq 0 ]
then
   echo "Import heat db failed: $?"
   exit 1
else
   echo "Import heat db: OK"
fi

keystone user-create --name heat --pass $HEAT_PASS
if [ ! $? -eq 0 ]
then
   echo "Create user 'heat' failed: $?"
   exit 1
else
   echo "Create user 'heat': OK"
fi

keystone user-role-add --user heat --tenant service --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'heat' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'heat': OK"
fi

keystone role-create --name heat_stack_owner
if [ ! $? -eq 0 ]
then
   echo "Create role 'heat_stack_owner' failed: $?"
   exit 1
else
   echo "Create role 'heat_stack_owner': OK"
fi

keystone user-role-add --user demo --tenant demo --role heat_stack_owner
if [ ! $? -eq 0 ]
then
   echo "Grant role 'heat_stack_owner' to user 'demo' failed: $?"
   exit 1
else
   echo "Grant role 'heat_stack_owner' to user 'demo': OK"
fi

keystone role-create --name heat_stack_user
if [ ! $? -eq 0 ]
then
   echo "Create role 'heat_stack_user' failed: $?"
   exit 1
else
   echo "Create role 'heat_stack_user': OK"
fi

keystone service-create --name heat --type orchestration --description "Orchestration"
if [ ! $? -eq 0 ]
then
   echo "Create service 'heat' failed: $?"
   exit 1
else
   echo "Create service 'heat': OK"
fi

keystone service-create --name heat-cfn --type cloudformation --description "Orchestration"
if [ ! $? -eq 0 ]
then
   echo "Create service 'heat-cfn' failed: $?"
   exit 1
else
   echo "Create service 'heat-cfn': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ orchestration / {print $2}') --publicurl http://controller:8004/v1/%\(tenant_id\)s --internalurl http://controller:8004/v1/%\(tenant_id\)s --adminurl http://controller:8004/v1/%\(tenant_id\)s --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'orchestration' failed: $?"
   exit 1
else
   echo "Create endpoint 'orchestration': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ cloudformation / {print $2}') --publicurl http://controller:8000/v1 --internalurl http://controller:8000/v1 --adminurl http://controller:8000/v1 --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'cloudformation' failed: $?"
   exit 1
else
   echo "Create endpoint 'cloudformation': OK"
fi

apt-get -y --force-yes install heat-api heat-api-cfn heat-engine python-heatclient
if [ ! $? -eq 0 ]
then
   echo "Install heat components failed: $?"
   exit 1
else
   echo "Install heat components: OK"
fi

rm -f /etc/heat/heat.conf

cd /etc/heat

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/heat.conf
if [ ! $? -eq 0 ]
then
   echo "wget heat.conf failed: $?"
   exit 1
else
   echo "Get heat.conf: OK"
   sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" heat.conf
   sed -i "s/heat:123456/heat:$HEAT_DBPASS/g" heat.conf
   sed -i "s/admin_password =/admin_password = $HEAT_PASS/g" heat.conf
fi

cd -

rm -f /var/lib/heat/heat.sqlite

su -s /bin/bash -c "heat-manage db_sync" heat
if [ ! $? -eq 0 ]
then
   echo "Sync heat db failed: $?"
   exit 1
else
   echo "Sync heat db: OK"
fi

service heat-api restart && service heat-api-cfn restart && service heat-engine restart
if [ ! $? -eq 0 ]
then
   echo "Restart heat services failed: $?"
   exit 1
else
   echo "Restart heat services: OK"
fi

# Configure ceilometer
apt-get -y --force-yes install mongodb-server mongodb-clients python-pymongo
if [ ! $? -eq 0 ]
then
   echo "Install mongodb failed: $?"
   exit 1
else
   echo "Install mongodb: OK"
fi

rm -f /etc/mongodb.conf

cd /etc
wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/mongodb.conf
if [ ! $? -eq 0 ]
then
   echo "wget mongodb.conf failed: $?"
   exit 1
else
   echo "Get mongodb.conf: OK"
   sed -i "s/bind_ip =/bind_ip = $mgr_ip/g" mongodb.conf
fi

cd -

service mongodb restart
if [ ! $? -eq 0 ]
then
   echo "Restrat mongodb failed: $?"
   exit 1
else
   echo "Restart mongodb: OK"
fi

sleep 3

# Create the ceilometer database
mongo --host controller --eval 'db = db.getSiblingDB("ceilometer");db.addUser({user: "ceilometer",pwd: "$CEILOMETER_DBPASS",roles: [ "readWrite", "dbAdmin" ]})'
if [ ! $? -eq 0 ]
then
   echo "Create the ceilometer database failed: $?"
   exit 1
else
   echo "Create the ceilometer database: OK"
fi

keystone user-create --name ceilometer --pass $CEILOMETER_PASS
if [ ! $? -eq 0 ]
then
   echo "Create user 'ceilometer' failed: $?"
   exit 1
else
   echo "Create user 'ceilometer': OK"
fi

keystone user-role-add --user ceilometer --tenant service --role admin
if [ ! $? -eq 0 ]
then
   echo "Grant 'admin' role to user 'ceilometer' failed: $?"
   exit 1
else
   echo "Grant 'admin' role to user 'ceilometer': OK"
fi

keystone service-create --name ceilometer --type metering --description "Telemetry"
if [ ! $? -eq 0 ]
then
   echo "Create service 'ceilometer' failed: $?"
   exit 1
else
   echo "Create service 'ceilometer': OK"
fi

keystone endpoint-create --service-id $(keystone service-list | awk '/ metering / {print $2}') --publicurl http://controller:8777 --internalurl http://controller:8777 --adminurl http://controller:8777 --region regionOne
if [ ! $? -eq 0 ]
then
   echo "Create endpoint 'metering' failed: $?"
   exit 1
else
   echo "Create endpoint 'metering': OK"
fi

apt-get -y --force-yes install ceilometer-api ceilometer-collector ceilometer-agent-central ceilometer-agent-notification ceilometer-alarm-evaluator ceilometer-alarm-notifier python-ceilometerclient
if [ ! $? -eq 0 ]
then
   echo "Install ceilometer components failed: $?"
   exit 1
else
   echo "Install ceilometer components: OK"
fi

rm -f /etc/ceilometer/ceilometer.conf

cd /etc/ceilometer

wget http://$TFTP_SERVER/yum_repo/images/os/openstack/config/ceilometer.conf
if [ ! $? -eq 0 ]
then
   echo "wget ceilometer.conf failed: $?"
   exit 1
else
   echo "Get ceilometer.conf: OK"
   sed -i "s/admin_password =/admin_password = $CEILOMETER_PASS/g" ceilometer.conf
   sed -i "s/rabbit_password =/rabbit_password = $RABBIT_PASS/g" ceilometer.conf
   sed -i "s/os_password =/os_password = $CEILOMETER_PASS/g" ceilometer.conf
   sed -i "s/ceilometer:123456/ceilometer:$CEILOMETER_DBPASS/g" ceilometer.conf
fi

cd -

service ceilometer-agent-central restart && service ceilometer-agent-notification restart && service ceilometer-api restart && service ceilometer-collector restart && service ceilometer-alarm-evaluator restart && service ceilometer-alarm-notifier restart
if [ ! $? -eq 0 ]
then
   echo "Restart ceilometer services failed: $?"
   exit 1
else
   echo "Restart ceilometer services: OK"
fi
   
echo "Install openstack controller node successfully!"

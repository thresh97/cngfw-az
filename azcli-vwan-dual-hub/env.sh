# Parameters (make changes based on your requirements)
# cngfw only supported in certain regions
# https://docs.paloaltonetworks.com/cloud-ngfw/azure/cloud-ngfw-for-azure/getting-started-with-cngfw-for-azure/supported-regions-and-zones

# Log Analytics Workspace for NetworkWatcher
prefix=mharms-00
region1=eastus	        #set region1
region2=centralus 		#set region2
rg=${prefix}-cngfw      #set resource group
vwanname=${prefix}-vwan #set vWAN name

hub1name=${prefix}-hub1 #set Hub1 name
hub1prefix=10.251.0.0/16
hub2name=${prefix}-hub2 #set Hub2 name
hub2prefix=10.252.0.0/16

username=azureuser      #set username
password="This4pass123" #set password
vmsize=Standard_DS1_v2  #set VM Size

sshpubkey="$HOME/.ssh/id_rsa.pub"
cloudinit="cloud-init.txt"

nsgnameregion1=default-nsg-$hub1name-$region1 
nsgnameregion2=default-nsg-$hub2name-$region2

subnetname=main

branch1asn=65001
branch1prefix=192.168.0.0/22
branch1subnet1=192.168.0.0/24
branch1subnet2=192.168.1.0/24

branch2asn=65002
branch2prefix=192.168.128.0/22
branch2subnet1=192.168.128.0/24
branch2subnet2=192.168.129.0/24

spoke1prefix=172.16.1.0/24
spoke1subnet1=172.16.1.0/27

spoke2prefix=172.16.2.0/24
spoke2subnet1=172.16.2.0/27

spoke3prefix=172.16.3.0/24
spoke3subnet1=172.16.3.0/27

spoke4prefix=172.16.4.0/24
spoke4subnet1=172.16.4.0/27

spoke5prefix=172.16.5.0/24
spoke5subnet1=172.16.5.0/27

spoke6prefix=172.16.6.0/24
spoke6subnet1=172.16.6.0/27

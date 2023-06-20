#!/bin/bash

# based on ...
# https://github.com/dmauser/azure-virtualwan/tree/main/svh-ri-inter-region

# Create VWAN with two regional hubs.  Each hub wiht three spoke VNETs containing a single VM

ENV="env.sh"
if [ -f $ENV ] && [ -r $ENV ]
then
 source $ENV
else
 echo "ERROR: no $ENV in current working directory"
 exit
fi

sshkeys=""

if [ -f $sshpubkey ] && [ -r $sshpubkey ]
then
    sshkeys="--ssh-key-values $sshpubkey"
fi

customdata=""
if [ -f $cloudinit ] && [ -r $cloudinit ]
then
    customdata="--custom-data $cloudinit"
fi

# Pre-Requisites
# Check if virtual wan extension is installed if not install it
if ! az extension list | grep -q virtual-wan; then
    echo "virtual-wan extension is not installed, installing it now..."
    az extension add --name virtual-wan --only-show-errors
fi

# Adding script starting time and finish time
start=`date +%s`
echo "Script started at $(date)"

# Variables
mypip=$(curl -4 ifconfig.io -s)
# create rg
az group create -n $rg -l $region1 --output none

echo Creating vwan and both hubs...
# create virtual wan
az network vwan create -g $rg -n $vwanname --branch-to-branch-traffic true --location $region1 --type Standard --output none
az network vhub create -g $rg --name $hub1name --address-prefix $hub1prefix --vwan $vwanname --location $region1 --sku Standard --tags "hubSaaSPreview=true" --no-wait
az network vhub create -g $rg --name $hub2name --address-prefix $hub2prefix --vwan $vwanname --location $region2 --sku Standard --tags "hubSaaSPreview=true" --no-wait

echo Creating spoke VNETs...
# create spokes virtual network
# Region1
az network vnet create --address-prefixes $spoke1prefix -n spoke1 -g $rg -l $region1 --subnet-name $subnetname --subnet-prefixes $spoke1subnet1 --output none
az network vnet create --address-prefixes $spoke2prefix -n spoke2 -g $rg -l $region1 --subnet-name $subnetname --subnet-prefixes $spoke2subnet1 --output none
az network vnet create --address-prefixes $spoke3prefix -n spoke3 -g $rg -l $region1 --subnet-name $subnetname --subnet-prefixes $spoke3subnet1 --output none
# Region2
az network vnet create --address-prefixes $spoke4prefix -n spoke4 -g $rg -l $region2 --subnet-name $subnetname --subnet-prefixes $spoke4subnet1 --output none
az network vnet create --address-prefixes $spoke5prefix -n spoke5 -g $rg -l $region2 --subnet-name $subnetname --subnet-prefixes $spoke5subnet1 --output none
az network vnet create --address-prefixes $spoke6prefix -n spoke6 -g $rg -l $region2 --subnet-name $subnetname --subnet-prefixes $spoke6subnet1 --output none

echo Creating NSGs in both regions...
#Update NSGs:
az network nsg create --resource-group $rg --name $nsgnameregion1 --location $region1 -o none
az network nsg create --resource-group $rg --name $nsgnameregion2 --location $region2 -o none

# Add my home public IP to NSG for SSH acess
az network nsg rule create -g $rg --nsg-name $nsgnameregion1 -n 'default-allow-ssh' --direction Inbound --priority 100 --source-address-prefixes $mypip --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow inbound SSH" --output none
az network nsg rule create -g $rg --nsg-name $nsgnameregion2 -n 'default-allow-ssh' --direction Inbound --priority 100 --source-address-prefixes $mypip --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow inbound SSH" --output none

# Associated NSG to the VNET subnets (Spokes and Branches)
# az network vnet list -g $rg --query '[?location==`'$region1'`&&subnets[?name==`'$subnetname'`]].id'
for vnet in $(az network vnet list -g $rg --query '[?location==`'$region1'`].name' -o tsv)
do
    az network vnet subnet update -g $rg --vnet-name ${vnet} --name $subnetname --network-security-group $nsgnameregion1 -o none
done

for vnet in $(az network vnet list -g $rg --query '[?location==`'$region2'`].name' -o tsv)
do
    az network vnet subnet update -g $rg --vnet-name ${vnet} --name $subnetname --network-security-group $nsgnameregion2 -o none
done

echo Creating Spoke VMs...
# create a VM in each connected spoke
az vm create -n spoke1VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region1 --subnet $subnetname --vnet-name spoke1 --admin-username $username --admin-password $password --nsg $nsgnameregion1 --no-wait --only-show-errors ${sshkeys} ${customdata}
az vm create -n spoke2VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region1 --subnet $subnetname --vnet-name spoke2 --admin-username $username --admin-password $password --nsg $nsgnameregion1 --no-wait --only-show-errors ${sshkeys} ${customdata}
az vm create -n spoke3VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region1 --subnet $subnetname --vnet-name spoke3 --admin-username $username --admin-password $password --nsg $nsgnameregion1 --no-wait --only-show-errors ${sshkeys} ${customdata}
az vm create -n spoke4VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region2 --subnet $subnetname --vnet-name spoke4 --admin-username $username --admin-password $password --nsg $nsgnameregion2 --no-wait --only-show-errors ${sshkeys} ${customdata}
az vm create -n spoke5VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region2 --subnet $subnetname --vnet-name spoke5 --admin-username $username --admin-password $password --nsg $nsgnameregion2 --no-wait --only-show-errors ${sshkeys} ${customdata}
az vm create -n spoke6VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region2 --subnet $subnetname --vnet-name spoke6 --admin-username $username --admin-password $password --nsg $nsgnameregion2 --no-wait --only-show-errors ${sshkeys} ${customdata}

# 
echo Tagging Spoke VMs...
az vm update -n spoke1VM -g $rg --set tags.env=dev --set tags.type=vm --set tags.region=$region1  -o none --no-wait
az vm update -n spoke2VM -g $rg --set tags.env=test --set tags.type=vm --set tags.region=$region1  -o none --no-wait
az vm update -n spoke3VM -g $rg --set tags.env=ss --set tags.type=vm --set tags.region=$region1  -o none --no-wait
az vm update -n spoke4VM -g $rg --set tags.env=dev --set tags.type=vm --set tags.region=$region2  -o none --no-wait
az vm update -n spoke5VM -g $rg --set tags.env=test --set tags.type=vm --set tags.region=$region2  -o none --no-wait
az vm update -n spoke6VM -g $rg --set tags.env=ss --set tags.type=vm --set tags.region=$region2  -o none --no-wait

# Continue only if all VMs are created
echo Waiting VMs to complete provisioning...
az vm wait -g $rg --created --ids $(az vm list -g $rg --query '[].{id:id}' -o tsv) --only-show-errors -o none

#Enabling boot diagnostics for all VMs in the resource group 
echo Enabling boot diagnostics for all VMs in the resource group...

# enable boot diagnostics for all VMs in the resource group
az vm boot-diagnostics enable --ids $(az vm list -g $rg --query '[].{id:id}' -o tsv) -o none

echo Checking Hub1 provisioning status...
# Checking Hub1 provisioning and routing state 
prState=''
rtState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub show -g $rg -n $hub1name --query 'provisioningState' -o tsv)
    echo "$hub1name provisioningState="$prState
    sleep 5
done

while [[ $rtState != 'Provisioned' ]];
do
    rtState=$(az network vhub show -g $rg -n $hub1name --query 'routingState' -o tsv)
    echo "$hub1name routingState="$rtState
    sleep 5
done

echo Creating Hub1 vNET connections
# create spoke to Vwan connections to hub1
az network vhub connection create -n spoke1conn --remote-vnet spoke1 -g $rg --vhub-name $hub1name --no-wait
az network vhub connection create -n spoke2conn --remote-vnet spoke2 -g $rg --vhub-name $hub1name --no-wait
az network vhub connection create -n spoke3conn --remote-vnet spoke3 -g $rg --vhub-name $hub1name --no-wait

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke1conn --vhub-name $hub1name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke1conn provisioningState="$prState
    sleep 5
done

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke2conn --vhub-name $hub1name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke2conn provisioningState="$prState
    sleep 5
done

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke3conn --vhub-name $hub1name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke3conn provisioningState="$prState
    sleep 5
done

echo Checking Hub2 provisioning status...
# Checking Hub2 provisioning and routing state 
prState=''
rtState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub show -g $rg -n $hub2name --query 'provisioningState' -o tsv)
    echo "$hub2name provisioningState="$prState
    sleep 5
done

while [[ $rtState != 'Provisioned' ]];
do
    rtState=$(az network vhub show -g $rg -n $hub2name --query 'routingState' -o tsv)
    echo "$hub2name routingState="$rtState
    sleep 5
done

# create spoke to Vwan connections to hub2
az network vhub connection create -n spoke4conn --remote-vnet spoke4 -g $rg --vhub-name $hub2name --no-wait
az network vhub connection create -n spoke5conn --remote-vnet spoke5 -g $rg --vhub-name $hub2name --no-wait
az network vhub connection create -n spoke6conn --remote-vnet spoke6 -g $rg --vhub-name $hub2name --no-wait

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke4conn --vhub-name $hub2name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke4conn provisioningState="$prState
    sleep 5
done

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke5conn --vhub-name $hub2name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke5conn provisioningState="$prState
    sleep 5
done

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke6conn --vhub-name $hub2name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke6conn provisioningState="$prState
    sleep 5
done

# create route table and associate with subnets in branch and spokes to allow direct SSH from deployment client public IP
echo Creating and associating route tables for spokes and branches to allow SSH from ${myip}
az network route-table create -g $rg --location ${region1} --name backdoor-rt-${region1} --output none
az network route-table create -g $rg --location ${region2} --name backdoor-rt-${region2} --output none

# add routes to route table for public IP of this client that is running az cli commands
az network route-table route create -g $rg --route-table-name backdoor-rt-${region1} -n myip --address-prefix ${mypip}/32  --next-hop-type Internet --output none
az network route-table route create -g $rg --route-table-name backdoor-rt-${region2} -n myip --address-prefix ${mypip}/32  --next-hop-type Internet --output none

# associate regional route tables with main subnets in spokes and branches
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region1} --vnet-name spoke1 --output none --no-wait
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region1} --vnet-name spoke2 --output none --no-wait
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region1} --vnet-name spoke3 --output none --no-wait
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region2} --vnet-name spoke4 --output none --no-wait
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region2} --vnet-name spoke5 --output none --no-wait
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region2} --vnet-name spoke6 --output none --no-wait

# install network watcher agent on linux spoke VMs
echo Installing NetworkWatcherAgentLinux on spoke VMs
az vm extension set --vm-name spoke1VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none
az vm extension set --vm-name spoke2VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none
az vm extension set --vm-name spoke3VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none
az vm extension set --vm-name spoke4VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none
az vm extension set --vm-name spoke5VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none
az vm extension set --vm-name spoke6VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none

echo "Creating Log Analytics Workspace for NetworkWatcher"
az monitor log-analytics workspace create --location $region1 -g $rg --name ${prefix}-law --sku pergb2018 -o none
lawid=$(az monitor log-analytics workspace show -g $rg --name ${prefix}-law  --query id -o tsv)

echo Deployment has finished
# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."

# TODO
# add tags by env (dev,test,prod) to vnet, subnet, vm # done
# does ip-tag redistribution work for Panorama managed? # yes 
# 
# create vault with sub-ca (issuing) cert and key for decryption # done
# create script to create CA cert and key that can be imported into vault or pano TS...

# inject sub-ca as trusted issuing cert in spoke and branch VMs # done
#
# add cngfw deployment in both hubs # done 
# add routing intent policies for Internet and private traffic in both hubs # done
# create rulestack (duplicated or shared across regions)
#  east-west policy # done 
#  outbound policy # done
#  inbound policy and inbound NAT # not yet
# 
# decryption policy with managed identity ... # works with LRS
#
# test multiple SNAT IPs or Prefixes? # IP prefixes not currently supported
# 
# test non-RFC1918 private IP addresses # won't work for now
# 
# content push on bootstrap from TS setting
# 
# DNS Proxy policy, custom VNET dns
# 
# Security Profiles
#
# DG hierarchy with multi-sub MD NG for DAG?
# X-Region inbound NATs don't look like they'll work.  far region VNET eff routes and sec rules don't have references to far hub cidr
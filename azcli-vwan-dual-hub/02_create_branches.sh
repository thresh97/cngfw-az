#!/bin/bash

# based on ...
# https://github.com/dmauser/azure-virtualwan/tree/main/svh-ri-inter-region

# Create two branch VNETs attached to regional VWAN hubs via site to site VPN.  Each branch VNET containing a single VM

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


# Adding script starting time and finish time
start=`date +%s`
echo "Script started at $(date)"

echo Creating branches VNETs...
# create location1 branch virtual network
az network vnet create --address-prefixes $branch1prefix -n branch1 -g $rg -l $region1 --subnet-name $subnetname --subnet-prefixes $branch1subnet1 --output none

# create location2 branch virtual network
az network vnet create --address-prefixes $branch2prefix -n branch2 -g $rg -l $region2 --subnet-name $subnetname --subnet-prefixes $branch2subnet1 --output none

echo Creating VMs in both branches...
# create a VM in each branch spoke
az vm create -n branch1VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region1 --subnet $subnetname --vnet-name branch1 --admin-username $username --admin-password $password --nsg $nsgnameregion1 --no-wait --only-show-errors  ${sshkeys} ${customdata}
az vm create -n branch2VM  -g $rg --image ubuntults --public-ip-sku Standard --size $vmsize -l $region2 --subnet $subnetname --vnet-name branch2 --admin-username $username --admin-password $password --nsg $nsgnameregion2 --no-wait --only-show-errors  ${sshkeys} ${customdata}

echo Creating VPN Gateways in both branches...
# create pips for VPN GW's in each branch
az network public-ip create -n branch1-vpngw-pip -g $rg --location $region1 --sku Basic --output none
az network public-ip create -n branch2-vpngw-pip -g $rg --location $region2 --sku Basic --output none

# create VPN gateways
az network vnet subnet create -g $rg --vnet-name branch1 -n GatewaySubnet --address-prefixes $branch1subnet2 --output none
az network vnet-gateway create -n branch1-vpngw --public-ip-addresses branch1-vpngw-pip -g $rg --vnet branch1 --asn $branch1asn --gateway-type Vpn -l $region1 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait 
az network vnet subnet create -g $rg --vnet-name branch2 -n GatewaySubnet --address-prefixes $branch2subnet2 --output none
az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip -g $rg --vnet branch2 --asn $branch2asn --gateway-type Vpn -l $region2 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait

echo Tagging Branch VMs...
az vm update -n branch1VM -g $rg --set tags.env=prod --set tags.type=vm --set tags.region=dc1  -o none --no-wait
az vm update -n branch2VM -g $rg --set tags.env=prod --set tags.type=vm --set tags.region=dc2  -o none --no-wait

echo Creating Hub1 VPN Gateway...
# Creating VPN gateways in each Hub1
az network vpn-gateway create -n $hub1name-vpngw -g $rg --location $region1 --vhub $hub1name --no-wait 

echo Creating Hub2 VPN Gateway...
# Creating VPN gateways in each Hub2
az network vpn-gateway create -n $hub2name-vpngw -g $rg --location $region2 --vhub $hub2name --no-wait

echo Validating Branches VPN Gateways provisioning...
#Branches VPN Gateways provisioning status
prState=$(az network vnet-gateway show -g $rg -n branch1-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vnet-gateway delete -n branch1-vpngw -g $rg
    az network vnet-gateway create -n branch1-vpngw --public-ip-addresses branch1-vpngw-pip -g $rg --vnet branch1 --asn $branch1asn --gateway-type Vpn -l $region1 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait 
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vnet-gateway show -g $rg -n branch1-vpngw --query provisioningState -o tsv)
        echo "branch1-vpngw provisioningState="$prState
        sleep 5
    done
fi

prState=$(az network vnet-gateway show -g $rg -n branch2-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vnet-gateway delete -n branch2-vpngw -g $rg
    az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip -g $rg --vnet branch2 --asn $branch2asn --gateway-type Vpn -l $region2 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait 
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vnet-gateway show -g $rg -n branch2-vpngw --query provisioningState -o tsv)
        echo "branch2-vpngw provisioningState="$prState
        sleep 5
    done
fi

echo Validating vHubs VPN Gateways provisioning...
#vWAN Hubs VPN Gateway Status
prState=$(az network vpn-gateway show -g $rg -n $hub1name-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vpn-gateway delete -n $hub1name-vpngw -g $rg
    az network vpn-gateway create -n $hub1name-vpngw -g $rg --location $region1 --vhub $hub1name --no-wait
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vpn-gateway show -g $rg -n $hub1name-vpngw --query provisioningState -o tsv)
        echo $hub1name-vpngw "provisioningState="$prState
        sleep 5
    done
fi

prState=$(az network vpn-gateway show -g $rg -n $hub2name-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vpn-gateway delete -n $hub2name-vpngw -g $rg
    az network vpn-gateway create -n $hub2name-vpngw -g $rg --location $region2 --vhub $hub2name --no-wait
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vpn-gateway show -g $rg -n $hub2name-vpngw --query provisioningState -o tsv)
        echo $hub2name-vpngw "provisioningState="$prState
        sleep 5
    done
fi

echo Building VPN connections from VPN Gateways to the respective Branches...
# get bgp peering and public ip addresses of VPN GW and VWAN to set up connection
# Branch 1 and Hub1 VPN Gateway variables
bgp1=$(az network vnet-gateway show -n branch1-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
pip1=$(az network vnet-gateway show -n branch1-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh1gwbgp1=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
vwanh1gwpip1=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh1gwbgp2=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]' -o tsv)
vwanh1gwpip2=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0]' -o tsv)

# Branch 2 and Hub2 VPN Gateway variables
bgp2=$(az network vnet-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
pip2=$(az network vnet-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh2gwbgp1=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
vwanh2gwpip1=$(az network vpn-gateway show -n $hub2name-vpngw  -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanh2gwbgp2=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]' -o tsv)
vwanh2gwpip2=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0]' -o tsv)

# create virtual wan vpn site
az network vpn-site create --ip-address $pip1 -n site-branch1 -g $rg --asn $branch1asn --bgp-peering-address $bgp1 -l $region1 --virtual-wan $vwanname --device-model 'Azure' --device-vendor 'Microsoft' --link-speed '50' --with-link true --output none
az network vpn-site create --ip-address $pip2 -n site-branch2 -g $rg --asn $branch2asn --bgp-peering-address $bgp2 -l $region2 --virtual-wan $vwanname --device-model 'Azure' --device-vendor 'Microsoft' --link-speed '50' --with-link true --output none

# create virtual wan vpn connection
az network vpn-gateway connection create --gateway-name $hub1name-vpngw -n site-branch1-conn -g $rg --enable-bgp true --remote-vpn-site site-branch1 --internet-security --shared-key 'abc123' --output none
az network vpn-gateway connection create --gateway-name $hub2name-vpngw -n site-branch2-conn -g $rg --enable-bgp true --remote-vpn-site site-branch2 --internet-security --shared-key 'abc123' --output none

# create connection from vpn gw to local gateway and watch for connection succeeded
az network local-gateway create -g $rg -n lng-$hub1name-gw1 --gateway-ip-address $vwanh1gwpip1 --asn 65515 --bgp-peering-address $vwanh1gwbgp1 -l $region1 --output none
az network vpn-connection create -n branch1-to-$hub1name-gw1 -g $rg -l $region1 --vnet-gateway1 branch1-vpngw --local-gateway2 lng-$hub1name-gw1 --enable-bgp --shared-key 'abc123' --output none

az network local-gateway create -g $rg -n lng-$hub1name-gw2 --gateway-ip-address $vwanh1gwpip2 --asn 65515 --bgp-peering-address $vwanh1gwbgp2 -l $region1 --output none
az network vpn-connection create -n branch1-to-$hub1name-gw2 -g $rg -l $region1 --vnet-gateway1 branch1-vpngw --local-gateway2 lng-$hub1name-gw2 --enable-bgp --shared-key 'abc123' --output none

az network local-gateway create -g $rg -n lng-$hub2name-gw1 --gateway-ip-address $vwanh2gwpip1 --asn 65515 --bgp-peering-address $vwanh2gwbgp1 -l $region2 --output none
az network vpn-connection create -n branch2-to-$hub2name-gw1 -g $rg -l $region2 --vnet-gateway1 branch2-vpngw --local-gateway2 lng-$hub2name-gw1 --enable-bgp --shared-key 'abc123' --output none

az network local-gateway create -g $rg -n lng-$hub2name-gw2 --gateway-ip-address $vwanh2gwpip2 --asn 65515 --bgp-peering-address $vwanh2gwbgp2 -l $region2 --output none
az network vpn-connection create -n branch2-to-$hub2name-gw2 -g $rg -l $region2 --vnet-gateway1 branch2-vpngw --local-gateway2 lng-$hub2name-gw2 --enable-bgp --shared-key 'abc123' --output none

# associate regional route tables with main subnets in spokes and branches
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region1} --vnet-name branch1 --output none --no-wait
az network vnet subnet update -g $rg --name $subnetname --route-table backdoor-rt-${region2} --vnet-name branch2 --output none --no-wait

# install network watcher agent on linux branch VMs
echo Installing NetworkWatcherAgentLinux on branch VMs
az vm extension set --vm-name branch1VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none
az vm extension set --vm-name branch2VM -g $rg -n NetworkWatcherAgentLinux --publisher Microsoft.Azure.NetworkWatcher --version 1.4 -o none

echo Deployment has finished
# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."
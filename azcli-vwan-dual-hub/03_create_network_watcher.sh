#!/bin/bash

ENV="env.sh"
if [ -f $ENV ] && [ -r $ENV ]
then
 source $ENV
else
 echo "ERROR: no $ENV in current working directory"
 exit
fi


# Adding script starting time and finish time
start=`date +%s`
echo "Script started at $(date)"

lawid=$(az monitor log-analytics workspace show -g $rg --name ${prefix}-law  --query id -o tsv)

# use below query if RG has other VMs
#az vm list -g $rg -o tsv --query  '[?ends_with(name,`'VM'`)&&(starts_with(name,`'spoke'`)||starts_with(name,`'branch'`))].[id]'
echo "Create mesh of Network Watcher monitors and endpoints among spokes and branches"
VMS=$(az vm list -g $rg -o tsv --query  '[].[id]')
for SRC in $VMS
do
    src_vm_name=$(echo $SRC | sed -e 's|.*/||')
    test_groupname=$src_vm_name
    src_vm_loc=$(az vm show --ids $SRC --query location  -o tsv)
    monitor_name=${src_vm_name}-${src_vm_loc}
    az network watcher connection-monitor create -n $monitor_name -g $rg -l $src_vm_loc  \
        --test-group-name $test_groupname --endpoint-source-type AzureVM --endpoint-dest-type ExternalAddress \
        --endpoint-source-resource-id $SRC --endpoint-source-name  $src_vm_name \
        --endpoint-dest-address "1.1.1.1" --endpoint-dest-name checkip \
        --test-config-name Http --protocol Http --http-method GET --https-prefer false -o none --only-show-errors \
        --workspace-ids $lawid
    for DST in $VMS
    do
        if [ $SRC != $DST ]
        then
            dst_vm_name=$(echo $DST | sed -e 's|.*/||')
            az network watcher connection-monitor endpoint add --connection-monitor $monitor_name -l $src_vm_loc \
                --resource-id $DST --name $dst_vm_name --type AzureVM --dest-test-groups $test_groupname -o none --only-show-errors
        fi 
    done
done

echo Deployment has finished
# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."
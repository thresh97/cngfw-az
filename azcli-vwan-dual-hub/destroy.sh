#!/bin/bash

# Manually Delete
# Delete RI
# Delete CNGFW Resource
# Delete SaaS
# Delete LRS rules
# clear LRS managed idenity 
# change to none LRS sec services decryption certs
# clear LRS certs
# Delete LRS

# Delete RG 
source env.sh
# Adding script starting time and finish time
start=`date +%s`
echo "$0 Script started at $(date)"
az group delete --name $rg --yes --force-deletion-types Microsoft.Compute/virtualMachines
# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start))
echo "$0 Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."

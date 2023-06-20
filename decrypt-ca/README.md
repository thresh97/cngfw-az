# cngfw-az

## Egress Decryption plumbing for Azure Portal Managed Cloud NGFW 

- Create Self-signed CA certificate and key
- Create Azure Resource Group for Key Vault
- Create Azure Key Vault 
- Import CA cert and key to Azure Key Vault
- Create Managed Identity for Key Vault RG with certificate access policies

# Requirements
- openssl (tested with LibreSSL 3.3.6)
- bash (tested with bash 3.2)
- az (tested with 2.49.0)

# Use
1. Edit env.sh
2. ./cngfw-ca.sh

# Next Steps
1. Add Managed Identity to Local Rulestack
2. Add Trusted Certificate to Local Rulestack
3. Create Untrusted Certificate (Self-Signed) in Local Rulestack
4. Assign Untrust and Trust certificates in Security Services\Encrypted Threat Protection\Egress Decryption
5. Create Rule with "Egress Decryption" and "Logging" enabled

# Verification
1. Add Trusted Root CA certificate to client stores
2. Examine Decrypt logs
3. Verify issuer "curl -vvv ..." in client request

# Notes
- In preview, Panorama managed CNGFW cannot be configured to use Managed Identities to acccess key vaults.  Import CA to Panorama Template in Template Stack of CNGFW and use in Device Group Decryption policies




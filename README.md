# Exsolution
Shell script to install a [Exsolution Masternode](https://www.exsolution.io/) on a Linux server running Ubuntu 16.04. Use it on your own risk.  

***
## Installation:  

wget -q https://raw.githubusercontent.com/minerric/Sanchezium-1/master/sanchezium_install.sh  
bash exsolution_install.sh
***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the Exsolution Desktop Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **10000** EXT to **MN1**.  
4. Wait for 15 confirmations.  
5. Go to **Help -> "Debug window - Console"**  
6. Type the following command: **masternode outputs**  
7. Go to **Masternodes** tab  
8. Click **Create** and fill the details:  
* Alias: **MN1**  
* Address: **VPS_IP:PORT**  
* Privkey: **Masternode Private Key**  
* TxHash: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
* Reward address: leave blank  
* Reward %: leave blank  
9. Click **OK** to add the masternode  
10. Click **Start All**  

***

## Multiple MN on one VPS:

It is possible to run multiple **Exsolution** Master Nodes on the same VPS. Each MN will run under a different user you will choose during installation.  

***


## Usage:  

For security reasons **Exsolution** is installed under **exsolution** user, hence you need to **su - exsolution** before checking:    

```
SNCZ_USER=exsolution #replace exsolution with the MN username you want to check

su - $SNCZ_USER
exsolution-cli masternode status
exsolution-cli getinfo
```  

Also, if you want to check/start/stop **exsolution-cli** , run one of the following commands as **root**:

```
SNCZ_USER=exsolution  #replace exsolution with the MN username you want to check  
  
systemctl status $EXT_USER #To check the service is running.  
systemctl start $EXT_USER #To start ExsolutionD service.  
systemctl stop $EXT_USER #To stop ExsolutionD service.  
systemctl is-enabled $EXT_USER #To check whetether exsolution-cli service is enabled on boot or not.  
```  

***

  
Any donation is highly appreciated  

**EXT**: SQhM86PsFw4dxssXYFWdDSMQ8MuynRUx2f  
**BTC**: 1BzeQ12m4zYaQKqysGNVbQv1taN7qgS8gY 

# VMware.View.Broker
Powershell module for manipulating VMware Horizon View Connection Server

VMware PowerCLI provides module VMware.VimAutomation.HorizonView to connect with View connection server. Compared to origin VMware View PowerCLI (available as a Powershell snapin), this new module is not very easy to use. So I created this VMware.View.Broker module to provide more easy-to-use functions.

# Function List
Connect-ViewBroker: connect to View Connection Server. Once the connection is established, the connection server is saved as $global:defaultBroker. All further actions will be taken against this broker.

Get-ViewLicense: retrieve license information 

Add-ViewVC: add a virtual center

Remove-ViewVC: remove virtual center(s)

# Install
1. create a folder named VMware.View.Broker under Powershell module folder
2. copy VMware.View.Broker.psm1 and VMware.View.Broker.psd1 into the new folder
3. run the command below to load this module

Import-Module VMware.View.Broker

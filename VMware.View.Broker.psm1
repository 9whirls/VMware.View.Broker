<#
Copyright (c) 2017 Jian Liu (whirls9@hotmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

function encryptPassword ($plaintext) {
  $ss = New-Object VMware.Hv.SecureString
  $enc = [system.Text.Encoding]::UTF8
  $ss.Utf8String = $enc.GetBytes($plaintext)
  return $ss
}

class broker {
  $ip
  $username
  $password
  $server
  
  broker ($ip, $username, $password, $domain) {
    $this.ip = $ip
    $this.username = $username
    $this.password = $password
    $this.server = connect-hvserver -server $ip -user $username -password $password -domain $domain -ea stop
  }
  
  [object] get_license () {
    return $this.server.extensiondata.license.license_get()
  }
  
  [void] set_license ($key) {
    $this.server.extensiondata.license.license_set($key)
  }
  
  [VMware.Hv.VirtualCenterInfo[]] get_vcenter () {
    return $this.server.extensiondata.virtualcenter.virtualcenter_list()
  }
  
  [VMware.Hv.VirtualCenterId] add_vcenter ($name, $user, $password, $composertype, $composername, $composeruser, $composerpassword) {
    $vcPassword = encryptPassword($password)
    
    $server_spec = new-object VMware.Hv.ServerSpec -property @{
      servername = $name
      port = 443
      useSSL = $true
      username = $user
      password = $vcPassword
      serverType = "VIRTUAL_CENTER"
    }
    
    $vc_spec = new-object VMware.Hv.VirtualCenterSpec -property @{
      serverspec = $server_spec
      seSparseReclamationEnabled = $false
      limits = @{
        VcProvisioningLimit = 2
        VcPowerOperationsLimit = 5
        ViewComposerProvisioningLimit = 12
        ViewComposerMaintenanceLimit = 12
        InstantCloneEngineProvisioningLimit = 20
      }
      StorageAcceleratorData = @{
        enabled = $false
        defaultCacheSizeMB = 1024
      }
      viewComposerData = @{
        viewcomposertype = $composertype
      }
      disableVCInventoryLicenseAlarm = $true
      certificateOverride = $this.server.extensiondata.certificate.Certificate_Validate($server_spec).thumbprint
    }
    
    if ($composertype -eq "LOCAL_TO_VC") {
      $composer_spec = new-object VMware.Hv.ServerSpec -property @{
        servername = $name
        port = 18443
        useSSL = $true
        username = $user
        password = $vcPassword
        serverType = "VIEW_COMPOSER"
      }
      $vc_spec.viewComposerData.serverspec = $composer_spec
      $vc_spec.viewComposerData.certificateOverride = $this.server.extensiondata.certificate.Certificate_Validate($composer_spec).thumbprint
    }
    
    if ($composertype -eq "STANDALONE") {
      $composer_spec = new-object VMware.Hv.ServerSpec -property @{
        servername = $composername
        port = 18443
        useSSL = $true
        username = $composeruser
        password = encryptPassword($composerPassword)
        serverType = "VIEW_COMPOSER"
      }
      $vc_spec.viewComposerData.serverspec = $composer_spec
      $vc_spec.viewComposerData.certificateOverride = $this.server.extensiondata.certificate.Certificate_Validate($composer_spec).thumbprint
    }
    
    return $this.server.extensiondata.virtualcenter.virtualcenter_create($vc_spec)
  }
  
  remove_vcenter ($name) {
    $vclist = $this.get_vcenter() | ?{$_.serverspec.servername -match $name}
    foreach ($vc in $vclist) {
      $this.server.extensiondata.virtualcenter.virtualcenter_delete($vc.id)
    }
  }
  
  [VMware.Hv.FarmInfo[]] get_farm () {
    $qd = New-Object VMware.Hv.QueryDefinition -property @{
      queryEntityType = 'FarmSummaryView'
    }
    $results = $this.server.extensiondata.queryservice.queryservice_create($qd).results
    $farms = foreach ($r in $results) {$this.server.extensiondata.farm.farm_get($r.id)}
    return $farms
  }
  
  [VMware.Hv.RDSServerInfo[]] get_rdsserver () {
    $qd = New-Object VMware.Hv.QueryDefinition -property @{
      queryEntityType = 'RDSServerSummaryView'
    }
    $results = $this.server.extensiondata.queryservice.queryservice_create($qd).results
    $servers = foreach ($r in $results) {$this.server.extensiondata.rdsserver.rdsserver_get($r.id)}
    return $servers
  }
  
  [VMware.Hv.DesktopInfo[]] get_desktop () {
    $qd = New-Object VMware.Hv.QueryDefinition -property @{
      queryEntityType = 'DesktopSummaryView'
    }
    $results = $this.server.extensiondata.queryservice.queryservice_create($qd).results
    $desktops = foreach ($r in $results) {$this.server.extensiondata.desktop.desktop_get($r.id)}
    return $desktops
  }
  
  [VMware.Hv.ApplicationInfo[]] get_application () {
    $qd = New-Object VMware.Hv.QueryDefinition -property @{
      queryEntityType = 'ApplicationInfo'
    }
    $results = $this.server.extensiondata.queryservice.queryservice_create($qd).results
    $apps = foreach ($r in $results) {$this.server.extensiondata.application.application_get($r.id)}
    return $apps
  }
  
  [VMware.Hv.MachineInfo[]] get_machine () {
    $qd = New-Object VMware.Hv.QueryDefinition -property @{
      queryEntityType = 'MachineSummaryView'
    }
    $results = $this.server.extensiondata.queryservice.queryservice_create($qd).results
    $machines = foreach ($r in $results) {$this.server.extensiondata.machine.machine_get($r.id)}
    return $machines
  }
}

function Connect-ViewBroker {
  param(
    $name,
    $user,
    $password,
    $domain
  )
  
  $Global:defaultBroker = [broker]::new($name, $user, $password, $domain)
}

function Get-ViewLicense {
  $defaultBroker.get_license()
}

function Set-ViewLicense {
  param(
    $licensekey
  )
  $defaultBroker.set_license($licensekey)
}

function Get-ViewVC {
  $defaultBroker.get_vcenter()
}

function Get-ViewFarm {
  $defaultBroker.get_farm()
}

function Get-ViewRDSServer {
  $defaultBroker.get_rdsserver()
}

function Get-ViewDesktop {
  $defaultBroker.get_desktop()
}

function Get-ViewApplication {
  $defaultBroker.get_application()
}

function Get-ViewMachine {
  $defaultBroker.get_machine()
}

function Add-ViewVC {
  param(
    $name,
    $user,
    $password,
    [ValidateSet(
      "DISABLED",
      "LOCAL_TO_VC",
      "STANDALONE"
    )]
      $composertype,
    $composername,
    $composeruser,
    $composerpassword
  )
  
  $defaultBroker.add_vcenter($name, $user, $password, $composertype, $composername, $composeruser, $composerpassword)
}

function Remove-ViewVC {
  param(
    $name
  )
  
  $defaultBroker.remove_vcenter($name)
}

# This script is used to create two VMs on your hyper-v host that will be used as cluster nocde for the Azure Local cluster

$arrVMNAme = @()
$arrVMNAme += "ALNode1"
$arrVMNAme += "ALNode2"

# depending on the CPU in your host, you might want to adjust the numer of cores that the VMs get assigned
$CPUCores = 16

$VMSwitchName = "External"
$VHDXPath = "C:\MSLAB\AzureLocal"
$OSInstallIsoPath = "C:MSLAB\AzureLocal\AzureLocal23H2.25398.469.LCM.10.2503.0.3057.x64.en-us.iso"

# loops through the arry and create VMs
foreach($VMName in $arrVMNAme) {

    # Optional - Clean Up existing VM - remove the VM in Hyper-V
    # Remove-VM -Name $VMName -Force
    # delete the source files of the VM on the hyper-v host
    # if(test-path($VHDXPath + "\" + $VMName) -PathType Container) {remove-item -path ($VHDXPath + "\" + $VMName) -Recurse -Force }
    # if(test-path($VHDXPath + "\" + $VMName + "\" + $VMName + ".vhdx") -PathType Leaf) {remove-item -path ($VHDXPath + "\" + $VMName + ".vhdx") -Force }
    
    # Create the VM
    # Crete OS disk for the new VM
    New-VHD -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + ".vhdx") -SizeBytes 512GB
    
    # create the VM in HYper-V
    New-VM -Name $VMNAme -MemoryStartupBytes 32GB -VHDPath ($VHDXPath + "\" + $VMName + "\" + $VMName + ".vhdx") -Generation 2 -Path $VHDXPath
    
    # Disable dynamic memory
    Set-VMMemory -VMName $VMNAme -DynamicMemoryEnabled $false
    
    # Disable VM checkpoints
    Set-VM -VMName $VMNAme -CheckpointType Disabled
    
    # Remove the default network adapter
    Get-VMNetworkAdapter -VMName $VMNAme | Remove-VMNetworkAdapter
    
    # Add new network adapters
    Add-VmNetworkAdapter -VmName $VMNAme -Name "NIC1"
    Add-VmNetworkAdapter -VmName $VMNAme -Name "NIC2"
    Add-VmNetworkAdapter -VmName $VMNAme -Name "NIC3"
    Add-VmNetworkAdapter -VmName $VMNAme -Name "NIC4"
    
    # Attach all network adapters to the virtual switch
    Get-VmNetworkAdapter -VmName $VMNAme | Connect-VmNetworkAdapter -SwitchName $VMSwitchName
    
    # Enable MAC spoofing 
    Get-VmNetworkAdapter -VmName $VMNAme | Set-VmNetworkAdapter -MacAddressSpoofing On
    
    # Enable trunk port
    Get-VmNetworkAdapter -VmName $VMNAme | Set-VMNetworkAdapterVlan -Trunk -NativeVlanId 0 -AllowedVlanIdList 0-1000
    
    # Create a new key protector and assign it 
    $owner = Get-HgsGuardian UntrustedGuardian
    $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
    Set-VMKeyProtector -VMName $VMNAme -KeyProtector $kp.RawData
    
    # Enable the vTPM
    Enable-VmTpm -VMName $VMNAme
    
    # assign CPU cores 
    Set-VmProcessor -VMName $VMNAme -Count $CPUCores
    
    # Create extra drives
    new-VHD -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D1.vhdx") -SizeBytes 1024GB
    new-VHD -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D2.vhdx") -SizeBytes 1024GB
    new-VHD -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D3.vhdx") -SizeBytes 1024GB
    new-VHD -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D4.vhdx") -SizeBytes 1024GB
    new-VHD -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D5.vhdx") -SizeBytes 1024GB
    new-VHD -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D6.vhdx") -SizeBytes 1024GB
    
    # Attach drives to the newly created VHDXs for the VM
    Add-VMHardDiskDrive -VMName $VMNAme -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D1.vhdx")
    Add-VMHardDiskDrive -VMName $VMNAme -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D2.vhdx")
    Add-VMHardDiskDrive -VMName $VMNAme -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D3.vhdx")
    Add-VMHardDiskDrive -VMName $VMNAme -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D4.vhdx")
    Add-VMHardDiskDrive -VMName $VMNAme -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D5.vhdx")
    Add-VMHardDiskDrive -VMName $VMNAme -Path ($VHDXPath + "\" + $VMName + "\" + $VMName + "_D6.vhdx")
    
    # Disable time synchronization - only tested on english and german OS - ther's a chance, that this will not work with other languages and you need to manually disable timesync for the VM 
    Get-VMIntegrationService -VMName $VMNAme | Where-Object {$_.name -like "Time*"} | Disable-VMIntegrationService #ENU
    Get-VMIntegrationService -VMName $VMNAme | Where-Object {$_.name -like "Zeit*"} | Disable-VMIntegrationService #DE
    
    # Enable nested virtualization
    Set-VMProcessor -VMName $VMNAme -ExposeVirtualizationExtensions $true
    
    # Create a DVD drive with the 
    Add-VMDvdDrive -VMName $VMNAme -Path $OSInstallIsoPath 
    
    # move to top of the boot order
    $bootOrder = Get-VMFirmware -VMName $VMName
    foreach ($bootdev in $bootorder.BootOrder) {
        if ($bootdev.Device.Path -eq $OSInstallIsoPath) {
            Set-VMFirmware  -VMName $VMName -FirstBootDevice $bootdev
        }
    }
    
}

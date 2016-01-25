#Powershell Workflow to create a new Azure Resource Manage Virtual Machine

workflow New-ARMVM
{
		Param(
		[Parameter(Mandatory=$true)]
        [String]
		$VMName,
		[Parameter(Mandatory=$true)]
        [String]
		$VMSize,
		[Parameter(Mandatory=$true)]
        [String]
		$ResourceGroup,
		[Parameter(Mandatory=$true)]
        [String]
        $Subnet,
		[Parameter(Mandatory=$true)]
        [String]
		$Username,
		[Parameter(Mandatory=$true)]
        [String]
		$Password
	)


	#The name of the Automation Credential Asset this runbook will use to authenticate to Azure.
    $CredentialAssetName = "AutomationAcc";
	
	#Get the credential with the above name from the Automation Asset store
    $Cred = Get-AutomationPSCredential -Name $CredentialAssetName;
    if(!$Cred) {
        Throw "Could not find an Automation Credential Asset named '${CredentialAssetName}'. Make sure you have created one in this Automation Account."
    }

    #Connect to your Azure Account
	Add-AzureRmAccount -Credential $Cred;

	#The local admin account of the new VM
    $VMAdminPassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $VMCred = new-object System.Management.Automation.PSCredential ("$Username", $VMAdminPassword)	

    #Store variables for use later
    $rg = Get-AzureRMResourceGroup -Name $ResourceGroup
    $vNet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup
    $Sub = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $Subnet
    $Date = Get-Date -Format yyyymmdd
    $StorAccName = $VMName.toLower() + $Date

    #Create VM NIC
    $VMNic = New-AzureRmNetworkInterface -Name $VMName -ResourceGroupName $ResourceGroup -Location $rg.Location -SubnetId $Sub.Id

    #Create Storage Account
    $VMStor = New-AzureRmStorageAccount -Name $StorAccName -Type Standard_LRS -ResourceGroupName $ResourceGroup -Location $rg.Location
    
    #Create VM Configuration
	$vm = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
    $vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMName -Credential $VMCred -ProvisionVMAgent -EnableAutoUpdate
    $vm = Set-AzureRmVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2012-R2-Datacenter" -Version "latest"
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $VMNic.Id
    $VMDiskUri = $VMStor.PrimaryEndpoints.Blob.ToString() + "vhds/" + $VMName + "-OS-Disk"  + ".vhd"
    $vm = Set-AzureRmVMOSDisk -VM $vm -Name OSDisk -VhdUri $VMDiskUri -CreateOption fromImage
    $vm = Set-AzureRmVMBootDiagnostics -StorageAccountName $VMStor.StorageAccountName -VM $vm -ResourceGroupName $ResourceGroup -Enable

    #Create VM
    New-AzureRmVM -ResourceGroupName $ResourceGroup -Location $rg.Location -VM $vm
}
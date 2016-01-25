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
    $rg = InlineScript {Get-AzureRMResourceGroup -Name $ResourceGroup}
    $vNet = InlineScript {Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup}
    $Sub = InlineScript {Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $Subnet}
    $Date = InlineScript {Get-Date -Format yyyymmdd}
    $StorAccName = $VMName.toLower() + $Date

    #Create VM NIC
    $VMNic = InlineScript {New-AzureRmNetworkInterface -Name $VMName -ResourceGroupName $ResourceGroup -Location $rg.Location -SubnetId $Sub.Id}

    #Create Storage Account
    $VMStor = InlineScript {New-AzureRmStorageAccount -Name $StorAccName -Type Standard_LRS -ResourceGroupName $ResourceGroup -Location $rg.Location}
    
    #Create VM Configuration
	$vm = InlineScript {New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize}
    $vm = InlineScript {Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $VMName -Credential $VMCred -ProvisionVMAgent -EnableAutoUpdate}
    $vm = InlineScript {Set-AzureRmVMSourceImage -VM $vm -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2012-R2-Datacenter" -Version "latest"}
    $vm = InlineScript {Add-AzureRmVMNetworkInterface -VM $vm -Id $VMNic.Id}
    $VMDiskUri = $VMStor.PrimaryEndpoints.Blob.ToString() + "vhds/" + $VMName + "-OS-Disk"  + ".vhd"
    $vm = InlineScript {Set-AzureRmVMOSDisk -VM $vm -Name OSDisk -VhdUri $VMDiskUri -CreateOption fromImage}
    $vm = InlineScript {Set-AzureRmVMBootDiagnostics -StorageAccountName $VMStor.StorageAccountName -VM $vm -ResourceGroupName $ResourceGroup -Enable}

    #Create VM
    InlineScript {New-AzureRmVM -ResourceGroupName $ResourceGroup -Location $rg.Location -VM $vm}
}
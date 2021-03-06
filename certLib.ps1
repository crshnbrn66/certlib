#\certificate\certLib.ps1
#library for certificate installation
function Export-Certificates
{
     param
     (
         [string]
         $dir2write,

         [string]
         $certRootStore,

         [string]
         $certStore,

         [string]
         $pfxPass
     )

	if(!(test-path "$dir2write"))
	{mkdir "$dir2write"}
	$wroteCerts = Get-ChildItem "cert:\$certRootStore\$certStore" | Where-Object { $_.hasPrivateKey } | Foreach-Object { [system.IO.file]::WriteAllBytes("$dir2write\$($_.thumbprint).pfx", ($_.Export('PFX', $pfxPass)) ) }
	
}

function Import-PfxCertificate
{
     param
     (
         [string]
         $certPath,

         [string]
         $certRootStore,

         [string]
         $certStore,

         [string]
         $pfxPass
     )
 $imported = $false
   try
    {   
       $securepfxPass = ConvertTo-SecureString $pfxPass -AsPlainText -Force
       $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2  
       $pfx.import($certPath,$securepfxPass,'Exportable,PersistKeySet')  #http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509keystorageflags(v=vs.110).aspx
       $store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)  
       $store.open('MaxAllowed')  
       $store.add($pfx)  
       $store.close()   
       $imported = $pfx
    }
    catch
    { write-warning "could not import $certPath"}
    return $imported
}

function Is-ValidCertificate
{
     param
     (
         [Object]
         $certFile,

         [Object]
         $certPass
     )

	$returnCode = $false
	try
	{
		$secureCertPass = ConvertTo-SecureString $certPass -AsPlainText -Force
		$cert2Check = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile, $secureCertPass)
		if($cert2Check.notbefore -lt (Get-Date))
		{
			$returnCode = $false
		}
		$returnCode = $true
	} 
	catch 
	{
	 Write-Warning "Either a bad password:  or invalid file $certFile"
	}
	return $returnCode
}

Function Remove-PfxCertificate
{
     param
     (
         [string]
         $certPath,

         [string]
         $certRootStore,

         [string]
         $certStore,

         [string]
         $pfxPass
     )
   
   $securepfxPass = ConvertTo-SecureString $pfxPass -AsPlainText -Force
   $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2 
   try
    {  
       $pfx.import($certPath,$securepfxPass,'Exportable,PersistKeySet')  #http://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509keystorageflags(v=vs.110).aspx
       $store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)  
       $store.open('MaxAllowed')  
       $store.remove($pfx)  
       $store.close()
       return $pfx   
    }
    catch
    {
        Write-Warning "Cannot import $certPath"
    }

}

function Find-Certificate
{
     param
     (
         [Object]
         $certFile,

         [Object]
         $certPass,

         [Object]
         $certStoreObj
     )
   
    #certStoreOBJ = list of certificates in the cert store
    $c = $null
	$returnCode = $false
	try
	{
			$secureCertPass = ConvertTo-SecureString $certPass -AsPlainText -Force
			$cert2Check = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile, $secureCertPass)
            #$c =gci -Recurse -path cert:\* | where{$_.Thumbprint -eq ($cert2check.Thumbprint)} | select thumbprint, PSPath,psparentpath
            $c = $certStoreObj | Where-Object{$_.thumbprint -eq $cert2check.Thumbprint}
            if ($c)
            {
                write-host 'found' #($cert2Check.Thumbprint) " found in cert store here " $c.Pspath
			    $returnCode = $c
            }
            else
            { write-host 'not-found'}
	} 
	catch 
	{
	 Write-Warning "Either a bad password:  or invalid file $certFile"
	}
return $returnCode
}

function Get-CertStoreObjects
{
    $certStoreResults = $null
    try
    {
       $certStoreResults = Get-ChildItem -Recurse cert:\*
    }
    catch
    {
        Throw 'ERROR: cert store in-accessible. Are you admin?'
    }
    return $certStoreResults
}

function AddTo-CertStoreObject
{
     param
     (
         [Object]
         $certObject,

         [Object]
         $obj2Add
     )
    if($certObject | Where-Object{$_.thumbprint -notcontains $obj2Remove.thumbprint})
    { $certObject += $obj2Add}

    return $certObject
}
function Remove-FromCertStoreObject
{
     param
     (
         [Object]
         $certObject,

         [Object]
         $obj2Remove
     )

    $certObject = $certobject | Where-Object{$_.thumbprint -ne $obj2Remove.thumbprint}

    return $certObject
}

function Batch-Certificates
{
     param
     (
         [string]
         $dirPath,

         [string]
         $certRootStore,

         [string]
         $certStore,

         [string]
         $pfxPass,

         [Object]
         $certObject,

         [switch]
         $remove
     )

	$files = Get-ChildItem "$dirPath\*.pfx"
	foreach($file in $files)
	{
	  $isValidCert = Check-validCertificate $file $pfxPass
      if ($isValidCert)
      {
       
       $findCertificate = Find-Certificate $file $pfxpass $certObject
		if((!($findCertificate)) -or ($remove))
		{
            If($remove)
            {  $removed = Remove-PfxCertificate $file $certRootStore $certStore $pfxPass
               $certObject= removefrom-certStoreObject $certObject $removed
             }
            else 
             {
                $imported = Import-PfxCertificate $file $certRootStore $certStore $pfxPass
                $certObject = AddTo-CertStoreObject $certobject $imported
             }
  		 }	
	   }
       else
	   {Write-Output "$file is an invalid certificate"}
    }
    return $certObject
}

function Add-RemoveCertificate
{
     param
     (
         [string]
         $certFile,

         [string]
         $certRootStore,

         [string]
         $certStore,

         [string]
         $pfxPass,

         [Object]
         $certObject,

         [switch]
         $remove
     )

	$file = Get-ChildItem $certFile
    $isValidCert = Check-validCertificate $file $pfxPass
      if ($isValidCert)
      {
       
       $findCertificate = Find-Certificate $file $pfxpass $certObject
		if((!($findCertificate)) -or ($remove))
		{
            If($remove)
            {  $removed = Remove-PfxCertificate $file $certRootStore $certStore $pfxPass
               $certObject= removefrom-certStoreObject $certObject $removed
             }
            else 
             {
                $imported = Import-PfxCertificate $file $certRootStore $certStore $pfxPass
                $certObject = AddTo-CertStoreObject $certobject $imported
             }
  		 }	
	   }
       else
	   {Write-Output "$file is an invalid certificate"}
    return $certObject
}

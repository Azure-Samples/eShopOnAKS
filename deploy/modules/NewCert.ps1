param  (
    [string]$VaultName,
    [string]$CertName,
    [string]$SubjectName
)

$policy = New-AzKeyVaultCertificatePolicy -SubjectName $SubjectName `
    -IssuerName Self `
    -KeyUsage DigitalSignature `
    -Ekus "1.3.6.1.5.5.7.3.3" `
    -ValidityInMonths 12

Add-AzKeyVaultCertificate -VaultName $VaultName -Name $CertName -CertificatePolicy $policy

$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs["CertName"] = $CertName
<#
.SYNOPSIS
    Escrow (Backup) the existing Bitlocker key protectors to Azure AD (Intune)

.DESCRIPTION
    This script will verify the presence of existing recovery keys and have them escrowed (backed up) to Azure AD
    Great for switching away from MBAM on-prem to using Intune and Azure AD for Bitlocker key management

.INPUTS
    None

.NOTES
    Version       : 1.0
    Author        : Michael Mardahl
    Twitter       : @michael_mardahl
    Blogging on   : www.msendpointmgr.com
    Creation Date : 11 January 2021
    Purpose/Change: Initial script
    License       : MIT (Leave author credits)

.EXAMPLE
    Execute script as system or administrator
    .\Invoke-EscrowBitlockerToAAD.ps1

.NOTES
    If there is a policy mismatch, then you might get errors from the built-in cmdlet BackupToAAD-BitLockerKeyProtector.
    So I have wrapped the cmdlet in a try/catch in order to supress the error. This means that you will have to manually verify that the key was actually escrowed.
    Check MSEndpointMgr.com for solutions to get reporting stats on this.

#>

#region declarations

$DriveLetter = $env:SystemDrive

#endregion declarations

#region functions

function Test-Bitlocker ($BitlockerDrive) {
    #Tests the drive for existing Bitlocker keyprotectors
    try {
        Get-BitLockerVolume -MountPoint $BitlockerDrive -ErrorAction Stop
    } catch {
        Write-Output "Bitlocker was not found protecting the $BitlockerDrive drive. Terminating script!"
        exit 0
    }
}

function Get-KeyProtectorId ($BitlockerDrive) {
    #fetches the key protector ID of the drive
    $BitLockerVolume = Get-BitLockerVolume -MountPoint $BitlockerDrive
    $KeyProtector = $BitLockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }
    return $KeyProtector.KeyProtectorId
}

function Invoke-BitlockerEscrowAAD ($BitlockerDrive,$BitlockerKey) {
    #Escrow the key into Azure AD
    try {
        BackupToAAD-BitLockerKeyProtector -MountPoint $BitlockerDrive -KeyProtectorId $BitlockerKey -ErrorAction SilentlyContinue
        Write-Output "Attempted to escrow key in Azure AD - Please verify manually!"
    } catch {
        Write-Error "This should never have happend? Debug me!"
        exit 1
    }
    
 
}
function Invoke-BitlockerEscrowAD ($BitlockerDrive,$BitlockerKey) {

   #Escrow the key into AD
    try {
        Backup-BitLockerKeyProtector -MountPoint $BitlockerDrive -KeyProtectorId $BitlockerKey -ErrorAction SilentlyContinue
        Write-Output "Attempted to escrow key in AD - Please verify manually!"
    } catch {
        Write-Error "This should never have happend? Debug me!"
        exit 1
    }
}

#endregion functions

#region execute

Test-Bitlocker -BitlockerDrive $DriveLetter

$BLVs = Get-BitLockerVolume
foreach ($volume in $BLVs) {
    if ($volume.KeyProtector.RecoveryPassword) {
        foreach ($kp in $volume.KeyProtector) {
            if ($kp.RecoveryPassword) {
                Invoke-BitlockerEscrowAAD -BitlockerDrive $volume.MountPoint -BitlockerKey $kp.KeyProtectorId
                Invoke-BitlockerEscrowAD -BitlockerDrive $volume.MountPoint -BitlockerKey $kp.KeyProtectorId
               
            }
        }
    }
}

#endregion execute

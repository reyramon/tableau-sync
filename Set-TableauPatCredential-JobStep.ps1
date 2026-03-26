# =========================
# One-Time SQL Agent Job Step
# Create or update Tableau PAT in Windows Credential Manager
# Paste this whole file into a PowerShell job step running as SQL Agent.
# =========================

$targetName = "TableauSync/Prod/TableauPAT"
$credentialUserName = "TableauPAT"
$patSecret = "REPLACE_WITH_PAT_SECRET"

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class CredentialManagerNative
{
    private const int CRED_TYPE_GENERIC = 1;
    private const int CRED_PERSIST_LOCAL_MACHINE = 2;

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredWrite(ref CREDENTIAL userCredential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPointer);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern void CredFree(IntPtr credentialPointer);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL
    {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static void WriteGenericCredential(string targetName, string userName, string secret)
    {
        IntPtr secretPointer = IntPtr.Zero;
        try
        {
            secretPointer = Marshal.StringToCoTaskMemUni(secret);

            CREDENTIAL credential = new CREDENTIAL();
            credential.Type = CRED_TYPE_GENERIC;
            credential.TargetName = targetName;
            credential.UserName = userName;
            credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
            credential.CredentialBlob = secretPointer;
            credential.CredentialBlobSize = secret.Length * 2;

            bool success = CredWrite(ref credential, 0);
            if (!success)
            {
                throw new ApplicationException(
                    "CredWrite failed: " + new Win32Exception(Marshal.GetLastWin32Error()).Message);
            }
        }
        finally
        {
            if (secretPointer != IntPtr.Zero)
            {
                Marshal.ZeroFreeCoTaskMemUnicode(secretPointer);
            }
        }
    }

    public static bool TargetExists(string targetName)
    {
        IntPtr credentialPointer;
        bool success = CredRead(targetName, CRED_TYPE_GENERIC, 0, out credentialPointer);
        if (!success)
        {
            return false;
        }

        CredFree(credentialPointer);
        return true;
    }
}
"@

if ([string]::IsNullOrWhiteSpace($patSecret) -or $patSecret -eq "REPLACE_WITH_PAT_SECRET") {
    throw "Set `$patSecret to the Tableau PAT secret before running this job step."
}

Write-Host "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Host "Creating/updating generic credential target: $targetName"

[CredentialManagerNative]::WriteGenericCredential($targetName, $credentialUserName, $patSecret)

if (-not [CredentialManagerNative]::TargetExists($targetName)) {
    throw "Credential was written, but verification failed for target: $targetName"
}

Write-Host "Credential Manager target created successfully."
Write-Host "TargetName: $targetName"
Write-Host "CredentialUserName: $credentialUserName"
Write-Host "Set SSIS variable User::PatSecretCredentialTarget to this TargetName."

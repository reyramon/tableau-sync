using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace TableauUserSync.ScriptTasks.Common
{
    internal static class WindowsCredentialManager
    {
        private const int CRED_TYPE_GENERIC = 1;

        public static string ReadGenericCredentialSecret(string targetName)
        {
            if (string.IsNullOrWhiteSpace(targetName))
            {
                throw new ApplicationException("Credential Manager target name is required.");
            }

            IntPtr credentialPointer;
            bool success = CredRead(targetName, CRED_TYPE_GENERIC, 0, out credentialPointer);
            if (!success)
            {
                throw new ApplicationException(
                    "Unable to read Windows Credential Manager target '" + targetName + "'. " +
                    "Win32 error: " + new Win32Exception(Marshal.GetLastWin32Error()).Message);
            }

            try
            {
                CREDENTIAL credential = (CREDENTIAL)Marshal.PtrToStructure(credentialPointer, typeof(CREDENTIAL));
                if (credential.CredentialBlobSize <= 0 || credential.CredentialBlob == IntPtr.Zero)
                {
                    return string.Empty;
                }

                return Marshal.PtrToStringUni(credential.CredentialBlob, credential.CredentialBlobSize / 2);
            }
            finally
            {
                CredFree(credentialPointer);
            }
        }

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
    }
}

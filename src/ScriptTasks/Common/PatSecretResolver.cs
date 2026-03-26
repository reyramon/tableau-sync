using System;

namespace TableauUserSync.ScriptTasks.Common
{
    internal static class PatSecretResolver
    {
        public static string Resolve(string patSecret, string credentialTargetName)
        {
            if (!string.IsNullOrWhiteSpace(credentialTargetName))
            {
                string secretFromCredentialManager = WindowsCredentialManager.ReadGenericCredentialSecret(credentialTargetName);
                if (string.IsNullOrWhiteSpace(secretFromCredentialManager))
                {
                    throw new ApplicationException(
                        "Credential Manager target '" + credentialTargetName + "' was found, but the secret was empty.");
                }

                return secretFromCredentialManager;
            }

            if (string.IsNullOrWhiteSpace(patSecret))
            {
                throw new ApplicationException(
                    "PAT secret was not provided. Supply User::PatSecret or configure User::PatSecretCredentialTarget.");
            }

            return patSecret;
        }
    }
}

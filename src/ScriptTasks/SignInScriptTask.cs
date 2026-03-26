using System;
using TableauUserSync.ScriptTasks.Common;

namespace TableauUserSync.ScriptTasks
{
    internal sealed class SignInScriptTask
    {
        public TableauSignInResult Execute(string serverUrl, string apiVersion, string patName, string patSecret, string siteContentUrl)
        {
            TableauRestClient client = new TableauRestClient();
            return client.SignIn(serverUrl, apiVersion, patName, patSecret, siteContentUrl);
        }

        public TableauSignInResult ExecuteWithCredentialManager(
            string serverUrl,
            string apiVersion,
            string patName,
            string patSecret,
            string credentialTargetName,
            string siteContentUrl)
        {
            string resolvedPatSecret = PatSecretResolver.Resolve(patSecret, credentialTargetName);
            return Execute(serverUrl, apiVersion, patName, resolvedPatSecret, siteContentUrl);
        }
    }
}

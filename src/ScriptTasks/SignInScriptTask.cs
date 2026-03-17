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
    }
}

using System;
using TableauUserSync.ScriptTasks.Common;

namespace TableauUserSync.ScriptTasks
{
    internal sealed class CreateUserScriptTask
    {
        public string Execute(string serverUrl, string apiVersion, string siteId, string token, string username, string siteRole, bool isDryRun)
        {
            if (isDryRun)
            {
                return "DRY_RUN: create user skipped for " + username + " with role " + siteRole + ".";
            }

            TableauRestClient client = new TableauRestClient();
            return client.CreateUser(serverUrl, apiVersion, siteId, token, username, siteRole);
        }
    }
}

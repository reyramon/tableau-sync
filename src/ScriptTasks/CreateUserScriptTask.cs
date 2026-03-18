using System;
using TableauUserSync.ScriptTasks.Common;

namespace TableauUserSync.ScriptTasks
{
    internal sealed class CreateUserScriptTask
    {
        public string Execute(string serverUrl, string apiVersion, string siteId, string token, string username, string siteRole, string fullName, string email, bool isDryRun)
        {
            if (isDryRun)
            {
                return "DRY_RUN: create user skipped for " + username + " with role " + siteRole + " and full name " + (string.IsNullOrWhiteSpace(fullName) ? "<blank>" : fullName) + ".";
            }

            TableauRestClient client = new TableauRestClient();
            TableauCreateUserResult createResult = client.CreateUser(serverUrl, apiVersion, siteId, token, username, siteRole);
            string updateResult = client.UpdateUserProfile(serverUrl, apiVersion, siteId, token, createResult.UserId, fullName, email);

            return createResult.ResponseXml + Environment.NewLine + updateResult;
        }
    }
}

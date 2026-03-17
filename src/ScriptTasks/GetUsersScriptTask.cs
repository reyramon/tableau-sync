using System;
using System.Collections.Generic;
using TableauUserSync.ScriptTasks.Common;

namespace TableauUserSync.ScriptTasks
{
    internal sealed class GetUsersScriptTask
    {
        public IList<TableauUserRecord> ExecuteAllPages(string serverUrl, string apiVersion, string siteId, string token, int pageSize)
        {
            TableauRestClient client = new TableauRestClient();
            List<TableauUserRecord> allUsers = new List<TableauUserRecord>();

            int pageNumber = 1;
            int totalAvailable = 0;

            do
            {
                IList<TableauUserRecord> page = client.GetUsers(
                    serverUrl,
                    apiVersion,
                    siteId,
                    token,
                    pageSize,
                    pageNumber,
                    out totalAvailable);

                allUsers.AddRange(page);
                pageNumber++;
            }
            while (allUsers.Count < totalAvailable);

            return allUsers;
        }
    }
}

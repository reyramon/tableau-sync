using TableauUserSync.ScriptTasks.Common;

namespace TableauUserSync.ScriptTasks
{
    internal sealed class SignOutScriptTask
    {
        public void Execute(string serverUrl, string apiVersion, string token)
        {
            TableauRestClient client = new TableauRestClient();
            client.SignOut(serverUrl, apiVersion, token);
        }
    }
}

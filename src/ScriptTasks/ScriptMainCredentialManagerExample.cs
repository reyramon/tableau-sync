using System;
using TableauUserSync.ScriptTasks.Common;

namespace TableauUserSync.ScriptTasks
{
    internal static class ScriptMainCredentialManagerExample
    {
        public static string Example()
        {
            return
                "// Add a package variable named User::PatSecretCredentialTarget" + Environment.NewLine +
                "// Example value: TableauSync/Prod/TableauPAT" + Environment.NewLine +
                "string patName = GetStringVariable(\"User::PatName\");" + Environment.NewLine +
                "string patSecret = GetStringVariable(\"User::PatSecret\");" + Environment.NewLine +
                "string patSecretCredentialTarget = GetStringVariable(\"User::PatSecretCredentialTarget\");" + Environment.NewLine +
                "string resolvedPatSecret = PatSecretResolver.Resolve(patSecret, patSecretCredentialTarget);" + Environment.NewLine +
                "" + Environment.NewLine +
                "SignInScriptTask signInTask = new SignInScriptTask();" + Environment.NewLine +
                "TableauSignInResult signInResult = signInTask.Execute(" + Environment.NewLine +
                "    serverUrl," + Environment.NewLine +
                "    apiVersion," + Environment.NewLine +
                "    patName," + Environment.NewLine +
                "    resolvedPatSecret," + Environment.NewLine +
                "    siteContentUrl);";
        }
    }
}

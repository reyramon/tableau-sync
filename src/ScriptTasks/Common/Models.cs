using System;

namespace TableauUserSync.ScriptTasks.Common
{
    internal sealed class TableauSignInResult
    {
        public string Token { get; set; }

        public string SiteId { get; set; }

        public string UserId { get; set; }
    }

    internal sealed class TableauUserRecord
    {
        public string TableauUserId { get; set; }

        public string Username { get; set; }

        public string Email { get; set; }

        public string SiteRole { get; set; }

        public DateTime? LastLogin { get; set; }
    }

    internal sealed class TableauCreateUserResult
    {
        public string UserId { get; set; }

        public string ResponseXml { get; set; }
    }
}

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Security;
using System.Text;
using System.Xml;

namespace TableauUserSync.ScriptTasks.Common
{
    internal sealed class TableauRestClient
    {
        public TableauSignInResult SignIn(string serverUrl, string apiVersion, string patName, string patSecret, string siteContentUrl)
        {
            string url = serverUrl.TrimEnd('/') + "/api/" + apiVersion + "/auth/signin";
            string payload =
                "<tsRequest>" +
                "<credentials personalAccessTokenName=\"" + EscapeXml(patName) + "\" personalAccessTokenSecret=\"" + EscapeXml(patSecret) + "\">" +
                "<site contentUrl=\"" + EscapeXml(siteContentUrl ?? string.Empty) + "\" />" +
                "</credentials>" +
                "</tsRequest>";

            string responseXml = SendRequest(url, "POST", null, payload, "application/xml");
            XmlDocument document = new XmlDocument();
            document.LoadXml(responseXml);

            XmlNamespaceManager ns = new XmlNamespaceManager(document.NameTable);
            ns.AddNamespace("t", document.DocumentElement.NamespaceURI);

            XmlNode credentialsNode = document.SelectSingleNode("//t:credentials", ns);
            XmlNode siteNode = document.SelectSingleNode("//t:site", ns);
            XmlNode userNode = document.SelectSingleNode("//t:user", ns);

            return new TableauSignInResult
            {
                Token = GetRequiredAttribute(credentialsNode, "token"),
                SiteId = GetRequiredAttribute(siteNode, "id"),
                UserId = userNode == null ? null : GetOptionalAttribute(userNode, "id")
            };
        }

        public IList<TableauUserRecord> GetUsers(string serverUrl, string apiVersion, string siteId, string token, int pageSize, int pageNumber, out int totalAvailable)
        {
            string url = string.Format(
                "{0}/api/{1}/sites/{2}/users?pageSize={3}&pageNumber={4}",
                serverUrl.TrimEnd('/'),
                apiVersion,
                siteId,
                pageSize,
                pageNumber);

            string responseXml = SendRequest(url, "GET", token, null, "application/xml");
            XmlDocument document = new XmlDocument();
            document.LoadXml(responseXml);

            XmlNamespaceManager ns = new XmlNamespaceManager(document.NameTable);
            ns.AddNamespace("t", document.DocumentElement.NamespaceURI);

            XmlNode paginationNode = document.SelectSingleNode("//t:pagination", ns);
            totalAvailable = 0;
            if (paginationNode != null)
            {
                int.TryParse(GetOptionalAttribute(paginationNode, "totalAvailable"), out totalAvailable);
            }

            List<TableauUserRecord> users = new List<TableauUserRecord>();
            XmlNodeList userNodes = document.SelectNodes("//t:user", ns);
            foreach (XmlNode userNode in userNodes)
            {
                users.Add(new TableauUserRecord
                {
                    TableauUserId = GetRequiredAttribute(userNode, "id"),
                    Username = GetRequiredAttribute(userNode, "name"),
                    Email = GetOptionalAttribute(userNode, "email"),
                    SiteRole = GetOptionalAttribute(userNode, "siteRole"),
                    LastLogin = ParseNullableDateTime(GetOptionalAttribute(userNode, "lastLogin"))
                });
            }

            return users;
        }

        public string CreateUser(string serverUrl, string apiVersion, string siteId, string token, string username, string siteRole)
        {
            string url = string.Format(
                "{0}/api/{1}/sites/{2}/users",
                serverUrl.TrimEnd('/'),
                apiVersion,
                siteId);

            string payload =
                "<tsRequest>" +
                "<user name=\"" + EscapeXml(username) + "\" siteRole=\"" + EscapeXml(siteRole) + "\" />" +
                "</tsRequest>";

            return SendRequest(url, "POST", token, payload, "application/xml");
        }

        public void SignOut(string serverUrl, string apiVersion, string token)
        {
            string url = serverUrl.TrimEnd('/') + "/api/" + apiVersion + "/auth/signout";
            SendRequest(url, "POST", token, string.Empty, "application/xml");
        }

        private static string SendRequest(string url, string method, string token, string body, string contentType)
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
            request.Method = method;
            request.Accept = "application/xml";
            request.ContentType = contentType;

            if (!string.IsNullOrWhiteSpace(token))
            {
                request.Headers["X-Tableau-Auth"] = token;
            }

            if (!string.IsNullOrEmpty(body))
            {
                byte[] bytes = Encoding.UTF8.GetBytes(body);
                request.ContentLength = bytes.Length;
                using (Stream requestStream = request.GetRequestStream())
                {
                    requestStream.Write(bytes, 0, bytes.Length);
                }
            }
            else
            {
                request.ContentLength = 0;
            }

            try
            {
                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                using (Stream responseStream = response.GetResponseStream())
                using (StreamReader reader = new StreamReader(responseStream))
                {
                    return reader.ReadToEnd();
                }
            }
            catch (WebException ex)
            {
                string errorBody = string.Empty;
                if (ex.Response != null)
                {
                    using (Stream responseStream = ex.Response.GetResponseStream())
                    using (StreamReader reader = new StreamReader(responseStream))
                    {
                        errorBody = reader.ReadToEnd();
                    }
                }

                throw new ApplicationException("Tableau REST call failed for URL: " + url + Environment.NewLine + errorBody, ex);
            }
        }

        private static string EscapeXml(string value)
        {
            return SecurityElement.Escape(value ?? string.Empty);
        }

        private static string GetRequiredAttribute(XmlNode node, string attributeName)
        {
            string value = GetOptionalAttribute(node, attributeName);
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new ApplicationException("Missing required Tableau XML attribute: " + attributeName);
            }

            return value;
        }

        private static string GetOptionalAttribute(XmlNode node, string attributeName)
        {
            if (node == null || node.Attributes == null || node.Attributes[attributeName] == null)
            {
                return null;
            }

            return node.Attributes[attributeName].Value;
        }

        private static DateTime? ParseNullableDateTime(string value)
        {
            DateTime parsed;
            if (DateTime.TryParse(value, out parsed))
            {
                return parsed;
            }

            return null;
        }
    }
}

namespace Nervestaple.WebService.Models.security
{
    /// <summary>
    /// Models the credentials for an account
    /// </summary>
    public class SimpleAccountCredentials : IAccountCredentials
    {
        /// <summary>
        /// The unique identifier for the account (i.e. ID, UID or
        /// sAMAccountName)
        /// </summary>
        public string Id { get; set; }
        
        /// <summary>
        /// The password for the account
        /// </summary>
        public string Password { get; set; }
    }
}
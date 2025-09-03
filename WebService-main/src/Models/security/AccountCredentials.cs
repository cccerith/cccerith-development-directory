namespace Nervestaple.WebService.Models.security
{
    /// <summary>
    /// Provides an interface all account credentials must implement
    /// </summary>
    public interface IAccountCredentials
    {
        /// <summary>
        /// The unique identifier for the account (i.e. ID, UID or
        /// sAMAccountName)
        /// </summary>
        string Id { get; set; }
        
        /// <summary>
        /// The password for the account
        /// </summary>
        string Password { get; set; }
    }
}
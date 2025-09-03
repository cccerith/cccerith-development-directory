using System.Collections.Generic;

namespace Nervestaple.WebService.Models.security
{
    /// <summary>
    /// Provides an interface all account classes must implement
    /// </summary>
    public interface IAccount
    {
        /// <summary>
        /// The unique ID (in the case of Active Directory, the sAMAccountName,
        /// in other cases an id or uid) of the account.
        /// </summary>
        string Id { get; set; }
        
        /// <summary>
        /// The common name for this account
        /// </summary>
        string FullName { get; set; }
        
        /// <summary>
        /// The email address for this account
        /// </summary>
        string Mail { get; set; }

        /// <summary>
        /// List of the common names for all of the account's groups
        /// </summary>
        List<string> Roles { get; set; }
    }
}
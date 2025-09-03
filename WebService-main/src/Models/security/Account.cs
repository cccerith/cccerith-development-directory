using System.Collections.Generic;

namespace Nervestaple.WebService.Models.security
{
    /// <summary>
    /// Provides a model of an account, this provides the base object for all
    /// of the more specialized account types
    /// </summary>
    public class Account : IAccount
    {
        /// <summary>
        /// Creates a new instance
        /// </summary>
        public Account()
        {
            
        }
        
        /// <summary>
        /// Creates a new account and sets the values of it's fields with the
        /// data in the provided account instance
        /// </summary>
        /// <param name="account">Account data used to populate this instance</param>
        public Account(Account account)
        {
            Id = account.Id;
            FullName = account.FullName;
            Mail = account.Mail;
            Roles = account.Roles;
        }

        /// <summary>
        /// Creates a new account instance and sets the values of its fields
        /// </summary>
        /// <param name="id">Unique account identifier</param>
        /// <param name="fullName">Full name</param>
        /// <param name="mail">Mail address</param>
        /// <param name="roles">List of associated roles</param>
        public Account(string id, string fullName, string mail, List<string> roles)
        {
            Id = id;
            FullName = fullName;
            Mail = mail;
            Roles = roles;
        }
        
        /// <summary>
        /// The unique ID (in the case of Active Directory, the sAMAccountName,
        /// in other cases the uid) of the account.
        /// </summary>
        public string Id { get; set; }
        
        /// <summary>
        /// The common name for this account
        /// </summary>
        public string FullName { get; set; }
        
        /// <summary>
        /// The email address for this account
        /// </summary>
        public string Mail { get; set; }

        /// <summary>
        /// List of the common names for all of the account's groups
        /// </summary>
        public List<string> Roles { get; set; }
    }
}
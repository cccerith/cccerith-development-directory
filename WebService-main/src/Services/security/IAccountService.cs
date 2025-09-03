using System.Threading.Tasks;
using Nervestaple.WebService.Models.security;

namespace Nervestaple.WebService.Services.security
{
    /// <summary>
    /// Provides the interface for the LDAP service
    /// </summary>
    public interface IAccountService
    {
        /// <summary>
        /// Returns an LdapAccount instance for the account with the provided
        /// unique identifier and password. A "null" value is returned if the
        /// unique identifier is not paired with the correct password or if the
        /// unique identifier is not present on the LDAP server.
        /// </summary>
        /// <param name="credentials">Account credentials</param>
        /// <returns>Matching account instance</returns>
        Account Authenticate(IAccountCredentials credentials);
        
        /// <summary>
        /// Returns an LdapAccount instance for the account with the provided
        /// unique identifier and password. A "null" value is returned if the
        /// unique identifier is not paired with the correct password or if the
        /// unique identifier is not present on the LDAP server.
        /// </summary>
        /// <param name="credentials">Account credentials</param>
        /// <returns>Matching account instance</returns>
        Task<Account> AuthenticateAsync(IAccountCredentials credentials);

        /// <summary>
        /// Returns the account information for the account with the matching
        /// unique identifier
        /// </summary>
        /// <param name="id">unique identifier of the account</param>
        /// <returns>Matching LDAP account instance</returns>
        Account Find(string id);
        
        /// <summary>
        /// Returns the account information for the account with the matching
        /// unique identifier
        /// </summary>
        /// <param name="id">unique identifier of the account</param>
        /// <returns>Matching LDAP account instance</returns>
        Task<Account> FindAsync(string id);
    }
}
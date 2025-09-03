using System.Threading.Tasks;
using Nervestaple.WebService.Models.security;
using Nervestaple.WebService.Repositories.security;

namespace Nervestaple.WebService.Services.security
{
    /// <summary>
    /// Provides a service for managing LDAP account instances
    /// </summary>
    public class AccountService : IAccountService
    {
        private readonly IAccountRepository _accountRepository;

        /// <summary>
        /// Creates a new instance and sets its repository
        /// </summary>
        /// <param name="repository">Repository for this instance</param>
        public AccountService(IAccountRepository repository)
        {
            _accountRepository = repository;
        }
        
        /// <inheritdoc/>
        public Account Authenticate(IAccountCredentials credentials) {
            return _accountRepository.AuthenticateAsync(credentials).Result;
        }

        /// <inheritdoc/>
        public async Task<Account> AuthenticateAsync(IAccountCredentials credentials) {
            return await _accountRepository.AuthenticateAsync(credentials);
        }

        /// <inheritdoc/>
        public Account Find(string id) {
            return _accountRepository.FindAsync(id).Result;
        }

        /// <inheritdoc/>
        public async Task<Account> FindAsync(string id) {
            return await _accountRepository.FindAsync(id);
        }
    }
}
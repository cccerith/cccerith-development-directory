using System.Threading.Tasks;
using Microsoft.AspNetCore.JsonPatch;
using Nervestaple.EntityFrameworkCore.Models.Entities;
using Nervestaple.WebService.Repositories;

namespace Nervestaple.WebService.Services
{
    /// <summary>
    /// Provides an abstract service with read and write operations that may be
    /// extended for a specific entity type.
    /// </summary>
    public class AbstractWebReadWriteService<T, K> : AbstractReadWriteService<T, K>, IWebReadWriteService<T, K> 
        where T: Entity<K>
        where K: struct {
        
        /// <summary>
        /// Repository of entity instances.
        /// </summary>
        protected new readonly IWebReadWriteRepository<T, K> Repository;

        /// <summary>
        /// Creates a new instance and sets its backing repository.
        /// </summary>
        /// <param name="repository">repository of entities</param>
        public AbstractWebReadWriteService(IWebReadWriteRepository<T, K> repository) : base(repository) {
            Repository = repository;
        }

        /// <inheritdoc /> 
        public T Update(K id, JsonPatchDocument<AbstractEntity> model) {
            return UpdateAsync(id, model).Result;
        }

        /// <inheritdoc /> 
        public async Task<T> UpdateAsync(K id, JsonPatchDocument<AbstractEntity> model) {
            return await Repository.UpdateAsync(id, model);
        }
    }
}
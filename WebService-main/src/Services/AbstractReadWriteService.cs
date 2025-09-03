using System.Threading.Tasks;
using Nervestaple.EntityFrameworkCore.Models.Entities;
using Nervestaple.EntityFrameworkCore.Repositories;

namespace Nervestaple.WebService.Services {

    /// <summary>
    /// Provides an abstract service with read/write operations that may be extended.
    /// </summary>
    public abstract class AbstractReadWriteService<T, K> : AbstractReadOnlyService<T, K>, IReadWriteService<T, K> 
        where T: Entity<K>
        where K: struct {
        
        /// <summary>
        /// Repository of entity instances.
        /// </summary>
        protected new readonly IReadWriteRepository<T, K> Repository;

        /// <summary>
        /// Creates a new instance and sets its backing repository.
        /// </summary>
        /// <param name="repository">repository of entities</param>
        public AbstractReadWriteService(IReadWriteRepository<T, K> repository) : base(repository) {
            Repository = repository;
        }

        /// <inheritdoc/>
        public virtual T Create(EditModel<T, K> model) {
            return CreateAsync(model).Result;
        }

        /// <inheritdoc/>
        public async Task<T> CreateAsync(EditModel<T, K> model) {
            return await Repository.CreateAsync(model);
        }

        /// <inheritdoc/>
        public virtual T Create(T instance) {
            return CreateAsync(instance).Result;
        }

        /// <inheritdoc/>
        public async Task<T> CreateAsync(T instance) {
            return await Repository.CreateAsync(instance);
        }

        /// <inheritdoc/>
        public virtual T Update(K id, EditModel<T, K> model) {
            return UpdateAsync(id, model).Result;
        }

        /// <inheritdoc/>
        public async Task<T> UpdateAsync(K id, EditModel<T, K> model) {
            return await Repository.UpdateAsync(id, model);
        }

        /// <inheritdoc/>
        public void Delete(K id)
        {
            DeleteAsync(id).RunSynchronously();
        }

        /// <inheritdoc/>
        public async Task DeleteAsync(K id) {
            await Repository.DeleteAsync(id);
        }
    }
}
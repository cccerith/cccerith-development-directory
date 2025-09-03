using System.Threading.Tasks;
using Nervestaple.EntityFrameworkCore.Models.Criteria;
using Nervestaple.EntityFrameworkCore.Models.Entities;
using Nervestaple.EntityFrameworkCore.Models.Parameters;
using Nervestaple.EntityFrameworkCore.Repositories;

namespace Nervestaple.WebService.Services {

    /// <summary>
    /// Provides an abstract service with read operations that may be extended
    /// for a specific entity type.
    /// </summary>
    public abstract class AbstractReadOnlyService<T, K> : IReadOnlyService<T, K> 
        where T: Entity<K>
        where K: struct {
        
        /// <summary>
        /// Repository of entity instances.
        /// </summary>
        protected readonly IReadOnlyRepository<T, K> Repository;

        /// <summary>
        /// SortBuilder used to sort queryables of instances.
        /// </summary>
        /// <returns>sort builder instance</returns>
        protected SortBuilder<T, K> SortBuilder = new SortBuilder<T, K>();

        /// <summary>
        /// Creates a new instance and sets its backing repository.
        /// </summary>
        /// <param name="repository">repository of entities</param>
        public AbstractReadOnlyService(IReadOnlyRepository<T, K> repository) {
            Repository = repository;
        }

        /// <inheritdoc/>
        T IReadOnlyService<T, K>.GetById(K id) {
            return GetByIdAsync(id).Result;
        }

        /// <inheritdoc/>
        public async Task<T> GetByIdAsync(K id) {
            return await Repository.FindAsync(id);
        }

        /// <inheritdoc/>
        PagedEntities<T> IReadOnlyService<T, K>.Get(IPageParameters pageParameters)
        {
            return GetAsync(pageParameters).Result;
        }

        /// <inheritdoc/>
        public async Task<PagedEntities<T>> GetAsync(IPageParameters pageParameters) {
            return await Repository.GetAsync(pageParameters);
        }

        /// <inheritdoc/>
        PagedEntities<T> IReadOnlyService<T, K>.Query(ISearchCriteria<T, K> searchCriteria, IPageParameters parameters) 
        { 
            return QueryAsync(searchCriteria, parameters).Result;
        }

        /// <inheritdoc/>
        public Task<PagedEntities<T>> QueryAsync(ISearchCriteria<T, K> searchCriteria, IPageParameters pageParameters) {
            return Repository.QueryAsync(searchCriteria, pageParameters);
        }
    }
}
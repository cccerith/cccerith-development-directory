using System.Threading.Tasks;
using Nervestaple.EntityFrameworkCore.Models.Criteria;
using Nervestaple.EntityFrameworkCore.Models.Entities;
using Nervestaple.EntityFrameworkCore.Models.Parameters;

namespace Nervestaple.WebService.Services {

    /// <summary>
    /// Provides an interface that the all read only service must implement.
    /// </summary>
    public interface IReadOnlyService<T, K> 
        where T: IEntity<K>
        where K: struct {

        /// <summary>
        /// Returns the instance with the matching unique identifier.
        /// </summary>
        /// <param name="id">unique identifier</param>
        /// <returns>matching instance</returns>
        T GetById(K id);
        
        /// <summary>
        /// Returns the instance with the matching unique identifier.
        /// </summary>
        /// <param name="id">unique identifier</param>
        /// <returns>matching instance</returns>
        Task<T> GetByIdAsync(K id);

        /// <summary>
        /// Returns a page of instances.
        /// </summary>
        /// <param name="pageParameters">parameters used when fetching page</param>
        /// <returns>page of instances</returns>
        PagedEntities<T> Get(IPageParameters pageParameters);
        
        /// <summary>
        /// Returns a page of instances.
        /// </summary>
        /// <param name="pageParameters">parameters used when fetching page</param>
        /// <returns>page of instances</returns>
        Task<PagedEntities<T>> GetAsync(IPageParameters pageParameters);

        /// <summary>
        /// Queries the instances according tot he provided search criteris and
        /// returns a page of the matching instances.
        /// </summary>
        /// <param name="searchCriteria">search criteria</param>
        /// <param name="pageParameters">parameters used when fetching page</param>
        /// <returns>page of instances</returns>
        PagedEntities<T> Query(ISearchCriteria<T, K> searchCriteria, IPageParameters pageParameters);
        
        /// <summary>
        /// Queries the instances according tot he provided search criteris and
        /// returns a page of the matching instances.
        /// </summary>
        /// <param name="searchCriteria">search criteria</param>
        /// <param name="pageParameters">parameters used when fetching page</param>
        /// <returns>page of instances</returns>
        Task<PagedEntities<T>> QueryAsync(ISearchCriteria<T, K> searchCriteria, IPageParameters pageParameters);
    }
}
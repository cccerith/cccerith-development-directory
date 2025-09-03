using System.Threading.Tasks;
using Nervestaple.EntityFrameworkCore.Models.Entities;

namespace Nervestaple.WebService.Services {

    /// <summary>
    /// Provides an interface that the all read/write service must implement.
    /// </summary>
    public interface IReadWriteService<T, K> : IReadOnlyService<T, K>
        where T: Entity<K>
        where K: struct
    {

        /// <summary>
        /// Returns a new entity populated with the provided data.
        /// <param name="model">Data object used to populate the new Entity</param>
        /// </summary>
        T Create(EditModel<T, K> model);
        
        /// <summary>
        /// Returns a new entity populated with the provided data.
        /// <param name="model">Data object used to populate the new Entity</param>
        /// </summary>
        Task<T> CreateAsync(EditModel<T, K> model);
        
        /// <summary>
        /// Adds the provided instance to the persistence context
        /// <param name="instance">instance to persist</param>
        /// </summary>
        T Create(T instance);
        
        /// <summary>
        /// Adds the provided instance to the persistence context
        /// <param name="instance">instance to persist</param>
        /// </summary>
        Task<T> CreateAsync(T instance);

        /// <summary>
        /// Returns a current copy of the entity after updating the Entity with
        /// the matching unique identifier with the values provided in the model
        /// <param name="id">Unique ID of the Entity to update</param>
        /// <param name="model">Data object used to update the Entity</param>
        /// </summary>
        T Update(K id, EditModel<T, K> model);
        
        /// <summary>
        /// Returns a current copy of the entity after updating the Entity with
        /// the matching unique identifier with the values provided in the model
        /// <param name="id">Unique ID of the Entity to update</param>
        /// <param name="model">Data object used to update the Entity</param>
        /// </summary>
        Task<T> UpdateAsync(K id, EditModel<T, K> model);

        /// <summary>
        /// Deletes the entity with the matching unique identifier.
        /// </summary>
        /// <param name="id">Unique identifier of the instance to delete</param>
        void Delete(K id);
        
        /// <summary>
        /// Deletes the entity with the matching unique identifier.
        /// </summary>
        /// <param name="id">Unique identifier of the instance to delete</param>
        Task DeleteAsync(K id);
    }
}
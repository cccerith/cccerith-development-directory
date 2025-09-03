using System.Threading.Tasks;
using Microsoft.AspNetCore.JsonPatch;
using Nervestaple.EntityFrameworkCore.Models.Entities;
using Nervestaple.EntityFrameworkCore.Repositories;

namespace Nervestaple.WebService.Repositories
{
    /// <inheritdoc/>
    public interface IWebReadWriteRepository <T, K>: IReadWriteRepository<T, K>
        where T: Entity<K>
        where K: struct
    {
        /// <summary>
        /// Returns a current copy of the entity after updating the Entity with
        /// the matching unique identifier with the values provided in the model
        /// <param name="id">Unique ID of the Entity to update</param>
        /// <param name="model">Data object used to update the Entity</param>
        /// </summary>
        T Update(K id, JsonPatchDocument<AbstractEntity> model);
        
        /// <summary>
        /// Returns a current copy of the entity after updating the Entity with
        /// the matching unique identifier with the values provided in the model
        /// <param name="id">Unique ID of the Entity to update</param>
        /// <param name="model">Data object used to update the Entity</param>
        /// </summary>
        Task<T> UpdateAsync(K id, JsonPatchDocument<AbstractEntity> model);
        
        /// <summary>
        /// Called after updating of the Entity and before that Entity is 
        /// persisted
        /// </summary>
        T PostUpdate(T instance, JsonPatchDocument<AbstractEntity> model);
        
        /// <summary>
        /// Called after updating of the Entity and before that Entity is 
        /// persisted
        /// </summary>
        Task<T> PostUpdateAsync(T instance, JsonPatchDocument<AbstractEntity> model);
    }
}
using System.Threading.Tasks;
using Microsoft.AspNetCore.JsonPatch;
using Nervestaple.EntityFrameworkCore.Models.Entities;

namespace Nervestaple.WebService.Services
{ 
    /// <summary>
    /// Provides an interface that the all read/write web services must implement.
    /// </summary>
    /// <typeparam name="T">Entity type</typeparam>
    /// <typeparam name="K">Entity's unique indentifier type</typeparam>
    public interface IWebReadWriteService<T, K> : IReadWriteService<T, K> 
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
    }
}
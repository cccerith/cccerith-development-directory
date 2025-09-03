using System.Threading.Tasks;
using Microsoft.AspNetCore.JsonPatch;
using Microsoft.EntityFrameworkCore;
using Nervestaple.EntityFrameworkCore.Models.Entities;
using Nervestaple.EntityFrameworkCore.Repositories;

namespace Nervestaple.WebService.Repositories
{
    /// <summary>
    /// Extends the standard repository with methods that can accept a
    /// JsonPatchDocument for updating entity instances.
    /// </summary>
    /// <typeparam name="T">Entity type</typeparam>
    /// <typeparam name="K">Entity's unique identifier type</typeparam>
    public class AbstractWebReadWriteRepository<T, K> : 
        AbstractReadWriteRepository<T, K>, IWebReadWriteRepository<T, K>
        where T : Entity<K> 
        where K : struct
    {
        /// <summary>
        /// Creates a new repository instance.
        /// </summary>
        /// <param name="context">the database context to use</param>
        /// <returns>a new instance</returns>
        public AbstractWebReadWriteRepository(DbContext context) : base(context) {

        }
        
        /// <summary>
        /// Returns a current copy of the entity after updating the Entity with
        /// the matching unique identifier with the values provided in the model
        /// <param name="id">Unique ID of the Entity to update</param>
        /// <param name="model">Data object used to update the Entity</param>
        /// </summary>
        public T Update(K id, JsonPatchDocument<AbstractEntity> model)
        {
            return HandlePatchUpdate(id, model);
        }

        /// <summary>
        /// Returns a current copy of the entity after updating the Entity with
        /// the matching unique identifier with the values provided in the model
        /// <param name="id">Unique ID of the Entity to update</param>
        /// <param name="model">Data object used to update the Entity</param>
        /// </summary>
        public async Task<T> UpdateAsync(K id, JsonPatchDocument<AbstractEntity> model) {
            return await HandlePatchUpdateAsync(id, model);
        }

        /// <summary>
        /// Called after updating of the Entity and before that Entity is 
        /// persisted
        /// </summary>
        public virtual T PostUpdate(T instance, JsonPatchDocument<AbstractEntity> model) {
            return PostUpdateAsync(instance, model).Result;
        }
        
        /// <summary>
        /// Called after updating of the Entity and before that Entity is 
        /// persisted
        /// </summary>
        public virtual async Task<T> PostUpdateAsync(T instance, JsonPatchDocument<AbstractEntity> model)
        {
            return instance;
        }

        /// <summary>
        /// Updates the entity with the values from the JSON patch document and
        /// then saves the entity
        /// </summary>
        /// <param name="id">unique identifier of the entity</param>
        /// <param name="model">model with new values</param>
        /// <returns>the updated entity instance</returns>
        protected virtual T HandlePatchUpdate(K id, JsonPatchDocument<AbstractEntity> model) {
            return HandlePatchUpdateAsync(id, model).Result;
        }

        /// <summary>
        /// Updates the entity with the values from the JSON patch document and
        /// then saves the entity
        /// </summary>
        /// <param name="id">unique identifier of the entity</param>
        /// <param name="model">model with new values</param>
        /// <returns>the updated entity instance</returns>
        protected virtual async Task<T> HandlePatchUpdateAsync(K id, JsonPatchDocument<AbstractEntity> model)
        {
            // fetch the target instance
            var instance = await FindAsync(id);

            // update the target instance's fields with the model's values
            model.ApplyTo(instance);

            // save and return the target instance
            Context.Update(instance);
            instance = await PostUpdateAsync(instance, model);
            await Context.SaveChangesAsync();
            return instance;
        }
    }
}
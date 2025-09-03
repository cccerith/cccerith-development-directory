![Continuous Integration](https://github.com/cmiles74/WebService/actions/workflows/ci.yml/badge.svg)

# Nervestaple.WebService

This library builds on the [Nervestaple.EntityFrameworkCore][1] library to help 
you quickly code up services that can orchestrate between your repositories. 
The "web" in "WebService" is there because we also provide a new
repository type and service that you may extend to get updates via 
[JsonPatchDocument][2] for free. This project is available as a package from
[NuGet.org][0], you may follow the directions on that page to add it to your 
project.

* [Nervestaple.Webservice NuGet Package][0]

```cs
public class ToDoItemService : AbstractReadWriteService<ToDoItem, long>, IToDoItemService
{
    private readonly IToDoItemRepository _toDoItemRepository;

    /// <inheritdoc/>
    public ToDoItemService(IToDoItemRepository repository) : base(repository)
    {
        _toDoItemRepository = repository;
    }
}
```

The service above supports all of the standard CRUD methods by passing them
through to the repository. You're now free to concentrate all of your time on
code that leverages other repositories or those many complex business rules!

This package also provides some hooks you can use to pull in other projects or
to integrate other libraries. We provide an `AccountService` to provide a place
to handle authentication as well as some models to support that in the 
`Services` namespaces. 

This library is a work in progress, please feel free to fork and send me pull
requests! `:-D`

## Documentation

This project uses [Doxygen][4] for documentation. Doxygen will collect inline 
comments from your code, along with any accompanying README files, and create 
a documentation website for the project. If you do not have Doxygen installed,
you can download it from their website and place it on your path. To run 
Doxygen...

    $ cd src
    $ doxygen

The documentation will be written to the `doc/html` folder at the root of the 
project, you can read this documentation with your web browser.

## Other Notes

Project Icon made by [Smashicons](https://www.flaticon.com/authors/smashicons) from 
[Flaticon](https://www.flaticon.com/) under the 
[Creative Commons license](http://creativecommons.org/licenses/by/3.0/).

----

[0]: https://www.nuget.org/packages/Nervestaple.WebService/
[1]: https://github.com/cmiles74/EntityFrameworkCore
[2]: https://docs.microsoft.com/en-us/aspnet/core/web-api/jsonpatch
[4]: http://www.doxygen.nl/


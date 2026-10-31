# Application Architecture

## Layering

```text
presentation  ->  domain  <-  data
   (UI)          (rules)     (network, db, prefs)
```

- **Domain** - the rules and the models. Knows nothing about UI, HTTP, or the database. Testable with no mocks.
- **Data** - implements the interfaces the domain defines: repositories, API clients, local storage.
- **Presentation** - renders state and dispatches user intent. No business rules.

The dependency arrow points inward. Presentation knows domain. Domain knows nothing.

## Layer rules

- No business logic in a UI callback. A button handler calls a controller method that lives outside the view.
- No framework types in the domain. No `Widget`, no `Response`, no ORM entity.
- The domain defines the interface; the data layer implements it.

```kotlin
// domain
interface OrderRepository {
    suspend fun orders(): List<Order>
}

// data
class RemoteOrderRepository(private val api: OrderApi) : OrderRepository {
    override suspend fun orders() = api.getOrders().map { it.toDomain() }
}
```

- DTOs and entities are converted to domain models at the boundary. A schema change in the API does not ripple into the rules.

## Feature-first structure

```text
src/
├── app/            # Application class, DI container, navigation host, theme
├── core/           # cross-cutting: network client, database, logging, result type
├── feature/
│   ├── login/
│   │   ├── data/          # repository impl, remote/local data sources
│   │   ├── domain/        # models, use cases, repository interfaces
│   │   └── presentation/  # screen, view model, components
│   └── catalog/
└── design/         # design system: colors, typography, components
```

- Group by feature, so one feature can be understood, changed, and deleted as a unit.
- Inside a feature, layer-first: data, domain, presentation.
- `core` holds only genuinely shared things. If it keeps growing, that is a sign features are not really independent.
- `design` holds the design system. Components used by one feature stay in that feature.

## Dependency injection

- Construct dependencies at the edges and pass them in. Prefer constructor injection.
- For large graphs, use a DI framework (Hilt, Koin, SwiftUI Environment, or a simple container).
- Scope carefully: singleton (the app), feature-scoped (a screen), or per-use. Do not make everything a singleton.
- Inject what you need, not the whole container. Injecting a "service locator" hides dependencies and makes them untestable.
- Use interfaces where the implementation may be swapped or faked in tests.

## State holders (ViewModel / Presenter / Controller)

- One per screen or feature. It exposes state and handles intents.
- Expose state as an immutable stream or a single state object. One atomic state object avoids inconsistent intermediate states.
- Handle intents, not events from the UI. The UI sends "user tapped submit"; the ViewModel decides what that means.
- Do not put Android/iOS/framework view types in the state holder. It should be testable without a UI.
- The ViewModel is the place where the use case is called and the result is mapped into UI state.

## Use cases

- A use case represents one application action. It is not mandatory for every operation, but it is worth it when there is real orchestration, validation, or policy.
- Keep use cases in the domain layer so they can be tested without Android or iOS.
- Do not create a use case that just forwards to a repository one-to-one. That is a layer with no value.

## Unidirectional data flow

```text
UI event -> ViewModel -> UseCase -> Repository -> DataSource
                              |
                              v
                        State (StateFlow)
                              |
                              v
                             UI
```

- The UI renders state and emits events. It never mutates state directly.
- The ViewModel is the only writer of state.
- State flows down, events flow up.

## Navigation

- Model navigation as state (a sealed class: `Screen.Home`, `Screen.Detail(id)`, `Screen.Settings`). One source of truth for "where the user is".
- Pass only IDs between screens, not whole objects. The destination loads its own data, so it stays correct when the source's data changes.
- Handle the system back button explicitly. It should follow the same model, not a separate stack.
- Deep links map into the same navigation model, so a link and a tap reach the same place.
- Do not put navigation state in a global store that survives process death incorrectly. Restore it deliberately.

## Modularization

- Split into modules when compile times hurt, when a boundary must be enforced by the build system, or when a team owns a piece independently.
- Gradle module boundaries enforce dependency rules at compile time. That is stronger than a convention.
- Feature modules should be able to depend on `core` and `design`, but not on each other except through explicit APIs.
- Beware over-modularization: a module per file is slower to build and adds ceremony.

## Error handling

- Represent failures as values in the domain: a sealed `Result` type, or typed domain errors. Exceptions make failure paths invisible to the type checker.
- Map domain errors to UI states at the presentation layer. The domain does not know about "show a snackbar".
- Distinguish: no network, permission denied, not found, unauthorized, validation failed, unknown.
- Never crash on an expected failure. Catch at the boundary and convert to a state.
- Include the technical cause in the log, but show a clean message in the UI.

## Testing

- Domain: pure unit tests, no framework. Fast and exhaustive.
- Data layer: integration tests against a fake or a real local database.
- Presentation: ViewModel tests with fake use cases, asserting the emitted state sequence.
- UI: instrumented tests for the critical flows only. They are slow and flaky; keep them few.
- Test the state machine, not the view. A ViewModel test that asserts "on submit, state becomes Loading, then Success or Error" covers most of the logic.

## Dependency rules

1. The domain layer imports nothing from the framework, the platform, or the data layer.
2. The data layer implements domain interfaces and imports the framework freely.
3. The presentation layer imports the domain and the framework.
4. No module imports a sibling feature module directly. Cross-feature navigation goes through the navigation model or an event.
5. Every cross-layer call to a data source goes through a repository, so caching and error mapping live in one place.

## Anti-patterns

- A "manager" or "helper" class that ends up importing everything.
- God objects that hold the navigation, the network client, and the preferences.
- Business logic inside an activity, a view controller, or a widget.
- Passing whole domain objects through navigation arguments.
- Direct platform API calls from the presentation layer.
- An `AppState` holding every piece of state in the app, causing a full recomposition on every change.

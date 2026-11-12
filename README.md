# Sightline map changes

A GitHub Action that comments on each pull request with what it does to the map of your .NET solution: endpoints added or removed, request flows that now reach something new, dependency injection registrations, project and package references, and the problems it adds or fixes. Reviewers see the shape of a change before reading the diff.

It runs [Sightline](https://sightline.revington.co), which reads the solution with the C# compiler, on the pull request and on its base commit, and compares the two.

## Use

```yaml
name: Map changes
on: pull_request

permissions:
  contents: read
  pull-requests: write   # to post the comment

jobs:
  map:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: ravindu-rev/sightline-action@v1
```

The comment is updated on every push to the pull request, and the result is also in the job summary.

## The comment

```markdown
### Sightline: what this change does to the map

**1 endpoint added · 1 request flow changed · 1 new problem**

#### New problems
- ❌ **A singleton holds on to a scoped service** (`src/Shop.Infrastructure/Background/OutboxWorker.cs:10`): OutboxWorker lives as long as the app (singleton), but it receives ShopDbContext, which is scoped. ...

#### Endpoints
- ➕ `POST /api/orders/{id}/refund` in `src/Shop.Api/Endpoints/OrderEndpoints.cs:31`

#### Request flows
- `POST /api/orders` now also reaches `PaymentGatewayClient.RefundAsync`, `HTTP (outbound)`
```

## Inputs

| Input | Default | What it does |
| --- | --- | --- |
| `solution` | from `sightline.json`, or the nearest solution | The `.sln`, `.slnx` or `.csproj` to read. |
| `version` | the latest release | The Sightline version to run, such as `0.4.0`. |
| `command` | none | Run Sightline this way instead, such as `dotnet sightline` in a repository set up with `sightline init` (run `dotnet tool restore` first). |
| `comment` | `true` | Post the result on the pull request. |
| `fail-on` | `never` | Fail the check when the pull request adds problems of this level: `error`, `warning` or `never`. |
| `github-token` | `github.token` | Token used to post the comment. |

The action sets up .NET 10, which Sightline runs on, and fetches the base commit itself, so the checkout needs no extra history.

The solution is read with the SDK its `global.json` asks for. When that is an older SDK, set it up in a step before this one, as for a build. Sightline restores the solution's NuGet packages itself; private feeds need the usual `dotnet nuget` set-up first.

Pull requests from forks get a read-only token, so the comment cannot be posted there. The step leaves a warning instead, and the job summary still shows the result.

## Also

- `sightline check` in CI fails the build on problems in the whole solution, with annotations in the pull request.
- The map itself, the VS Code extension and the rest: [sightline.revington.co](https://sightline.revington.co).

MIT license.

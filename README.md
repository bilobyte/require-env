# require-env

A small composite GitHub Action that fails a job when required configuration
variables or secrets are unset, empty, or whitespace-only.

## Usage

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: bilobyte/require-env@v1
        with:
          variables: |
            APP_ENV
            API_URL
          secrets: |
            DEPLOY_TOKEN
        env:
          APP_ENV: ${{ vars.APP_ENV }}
          API_URL: ${{ vars.API_URL }}
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}

      - run: ./deploy.sh
```

Names may be separated by commas, spaces, or newlines. They must be valid
environment-variable names.

Both inputs are optional, but at least one must contain a name. An empty
configuration is treated as an error so a typo cannot silently turn validation
into a no-op.

## Why values are passed through `env`

GitHub resolves the `vars` and `secrets` contexts before an action runs. An
action cannot receive the string `DEPLOY_TOKEN` and dynamically evaluate
`secrets.DEPLOY_TOKEN`. Mapping each value into `env` is therefore explicit,
safe, and supports values containing spaces or newlines.

The action never prints or emits values. It reports names only.

## Outputs

| Output | Meaning |
| --- | --- |
| `valid` | `true` when every required value is present; otherwise `false` |
| `missing-variables` | Comma-separated missing or empty variable names |
| `missing-secrets` | Comma-separated missing or empty secret names |

## Development

Run the dependency-free test suite:

```bash
./tests/test.sh
```

The action is composite and requires Bash, which is available on GitHub-hosted
Linux, macOS, and Windows runners.

## Release

Nothing in this repository publishes the action. When ready, create a release
and a major-version tag such as `v1`, then reference it from consumer
repositories. Pinning to a full commit SHA is safer for third-party actions.

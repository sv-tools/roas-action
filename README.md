# roas-action

GitHub Action that runs [`roas`](https://github.com/sv-tools/roas) to validate or
convert OpenAPI specifications (Swagger 2.0, OpenAPI 3.0.x / 3.1.x / 3.2.x).

The action is Docker-based and wraps the official
[`ghcr.io/sv-tools/roas`](https://github.com/sv-tools/roas/pkgs/container/roas)
image.

## Usage

### Validate

```yaml
- uses: sv-tools/roas-action@v1
  with:
    file: openapi.yaml
```

With external `$ref` loading and a few checks skipped:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    file: openapi.yaml
    load: file http
    ignore: missing-tags unused-tags
```

### Convert

Upconvert a spec to OpenAPI 3.2 and write the result next to the source:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: convert
    file: openapi.yaml
    to: v3_2
    output-file: openapi.v3_2.yaml
```

Layer overlay specs on top of a base via `merge`:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: convert
    file: openapi.yaml
    to: v3_2
    merge: |
      overlays/prod.yaml
      overlays/eu.yaml
    output-file: openapi.merged.yaml
```

## Inputs

| Name            | Required | Default    | Applies to | Description                                                                                   |
|-----------------|----------|------------|------------|-----------------------------------------------------------------------------------------------|
| `subcommand`    | no       | `validate` | both       | `validate` or `convert`.                                                                      |
| `file`          | yes      | —          | both       | Path to the OpenAPI spec (JSON or YAML), relative to the repo root.                           |
| `from`          | no       | —          | both       | Force the input spec version. One of `v2`, `v3_0`, `v3_1`, `v3_2`.                            |
| `to`            | yes\*    | —          | convert    | Target version for `convert`. Required when `subcommand: convert`.                            |
| `merge`         | no       | —          | convert    | Newline-separated list of overlay specs to merge on top of the base after version conversion. |
| `merge-options` | no       | —          | convert    | Whitespace-separated merge options (requires `merge`). See [merge options](#merge-options).   |
| `format`        | no       | auto       | both       | Force input format: `json` or `yaml`. By default inferred from the file extension.            |
| `load`          | no       | —          | validate   | Whitespace-separated list of `$ref` loaders to enable: `file`, `http`.                        |
| `ignore`        | no       | —          | validate   | Whitespace-separated validation checks to skip (see [check list](#validation-checks)).        |
| `print`         | no       | `false`    | validate   | If `true`, echo the parsed spec on stdout (diagnostics stay on stderr).                       |
| `output-format` | no       | match in   | convert    | Force output format: `json` or `yaml`.                                                        |
| `output-file`   | no       | stdout     | convert    | Write the converted spec to this path. If unset, output streams to the action log.            |

### Validation checks

Values accepted by `ignore` (passed straight through to `roas validate --ignore`):

```
missing-tags, external-references, invalid-urls, non-uniq-operation-ids,
unused-path-items, unused-tags, unused-schemas, unused-parameters,
unused-responses, unused-server-variables, unused-examples,
unused-request-bodies, unused-headers, unused-security-schemes,
unused-links, unused-callbacks, unused-media-types,
empty-info-title, empty-info-version, empty-response-description,
empty-external-documentation-url
```

Run `roas validate --help` for the description of each check.

### Merge options

Values accepted by `merge-options` (passed straight through as
`roas convert --merge-option`; defaults are "incoming wins" on scalar conflicts,
base retains `info`/`openapi`, refs replace silently, schemas are leaves):

- `base-wins` — reverse the default "incoming wins" policy.
- `error-on-conflict` — abort on the first real collision with a non-zero exit.
- `deep-merge-object-schemas` — deep-merge object schemas instead of leaf-replace.
- `merge-info` — allow `info`/`openapi`/`swagger` to merge instead of being preserved from base.
- `replace-lists-when-empty` — allow an empty incoming list (`servers`, `security`, …) to clear a populated base list.

## How it works

The action's `Dockerfile` is a multi-stage build:

1. `FROM ghcr.io/sv-tools/roas:latest AS roas` pulls the upstream distroless
   image only as a source for the `roas` binary.
2. The final stage is `debian:trixie-slim` (Debian 13, GLIBC 2.41 — required
   because the upstream `roas` binary is linked against GLIBC ≥ 2.39) with
   `ca-certificates` installed so `--load http` can validate TLS when
   following remote `$ref`s.
3. `entrypoint.sh` translates the action's `INPUT_*` env vars into the
   appropriate `roas` argv and `exec`s the binary.

GitHub builds this image the first time the action runs on a runner and caches
the layers for subsequent jobs.

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

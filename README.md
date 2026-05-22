# roas-action

GitHub Action that runs [`roas`](https://github.com/sv-tools/roas) to validate or
convert OpenAPI specifications (Swagger 2.0, OpenAPI 3.0.x / 3.1.x / 3.2.x) and to
validate, convert, or apply [OpenAPI Overlay](https://spec.openapis.org/overlay/latest.html)
documents (Overlay 1.0 / 1.1).

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
    to: v3.2
    output-file: openapi.v3_2.yaml
```

Layer additional specs on top of a base via `merge`:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: convert
    file: openapi.yaml
    to: v3.2
    merge: |
      overlays/prod.yaml
      overlays/eu.yaml
    output-file: openapi.merged.yaml
```

Apply OpenAPI Overlay documents while converting (`apply` runs last in the
pipeline: convert → merge → apply → collapse):

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: convert
    file: openapi.yaml
    to: v3.2
    apply: |
      overlays/add-servers.overlay.yaml
      overlays/redact-internal.overlay.yaml
    output-file: openapi.overlaid.yaml
```

### Overlay documents

Validate an OpenAPI Overlay document:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: overlay validate
    file: overlays/add-servers.overlay.yaml
```

Upconvert an Overlay 1.0 document to Overlay 1.1:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: overlay convert
    file: overlays/add-servers.overlay.yaml
    to: v1.1
    output-file: add-servers.v1_1.overlay.yaml
```

Apply one or more overlays to a target spec (`file` is the spec, `overlay`
lists the overlays, applied in order):

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: overlay apply
    file: openapi.yaml
    overlay: |
      overlays/add-servers.overlay.yaml
      overlays/redact-internal.overlay.yaml
    output-file: openapi.overlaid.yaml
```

## Inputs

"Applies to" abbreviations: **V** = `validate`, **C** = `convert`,
**OV** = `overlay validate`, **OC** = `overlay convert`, **OA** = `overlay apply`.

| Name            | Required | Default    | Applies to     | Description                                                                                        |
|-----------------|----------|------------|----------------|----------------------------------------------------------------------------------------------------|
| `subcommand`    | no       | `validate` | —              | `validate`, `convert`, `overlay validate`, `overlay convert`, or `overlay apply`.                  |
| `file`          | yes      | —          | all            | Positional input: the spec (V, C, OA) or the Overlay document (OV, OC), relative to the repo root. |
| `from`          | no       | —          | V, C           | Force the input spec version. One of `v2`, `v3.0`, `v3.1`, `v3.2`.                                 |
| `to`            | yes\*    | —          | C, OC          | Target version. For C: `v3.0`/`v3.1`/`v3.2` etc. For OC: `v1.0`/`v1.1`. Required for both.         |
| `merge`         | no       | —          | C              | Newline-separated list of specs to merge on top of the base after version conversion.              |
| `merge-options` | no       | —          | C              | Whitespace-separated merge options (requires `merge`). See [merge options](#merge-options).        |
| `apply`         | no       | —          | C              | Newline-separated Overlay documents to apply after merge (before collapse).                        |
| `overlay`       | yes\*    | —          | OA             | Newline-separated Overlay documents to apply to the spec. Required when `subcommand: overlay apply`.|
| `apply-options` | no       | —          | C, OA          | Whitespace-separated overlay apply options. See [overlay apply options](#overlay-apply-options).   |
| `collapse`      | no       | `false`    | C              | Lift inline components into the root bag and replace call sites with `$ref`s.                       |
| `format`        | no       | auto       | all            | Force input format: `json` or `yaml`. By default inferred from the file extension.                 |
| `load`          | no       | —          | V, C\*\*       | Whitespace-separated `$ref` loaders: `file`, `http`. On `convert` requires `collapse: true`.       |
| `ignore`        | no       | —          | V, OV          | Whitespace-separated checks to skip. See [validation checks](#validation-checks).                  |
| `print`         | no       | `false`    | V, OV          | If `true`, echo the parsed spec/overlay on stdout (diagnostics stay on stderr).                    |
| `output-format` | no       | match in   | C, OC, OA      | Force output format: `json` or `yaml`.                                                             |
| `output-file`   | no       | stdout     | all            | Write command output to this path. If unset, output streams to the action log.                    |

### Validation checks

For `validate`, values accepted by `ignore` (passed straight through to
`roas validate --ignore`):

```
missing-tags, external-references, invalid-urls, non-uniq-operation-ids,
unused-path-items, unused-tags, unused-schemas, unused-parameters,
unused-responses, unused-server-variables, unused-examples,
unused-request-bodies, unused-headers, unused-security-schemes,
unused-links, unused-callbacks, unused-media-types,
empty-info-title, empty-info-version, empty-response-description,
empty-external-documentation-url
```

For `overlay validate`, `ignore` accepts only `empty-info-title` and
`empty-info-version`.

Run `roas validate --help` (or `roas overlay validate --help`) for the
description of each check.

### Overlay apply options

Values accepted by `apply-options` (passed straight through as
`--apply-option`, for `convert` with `apply` and for `overlay apply`):

- `error-on-zero-match` — fail when an action's `target` JSONPath selects zero
  nodes. By default a zero-match action is a no-op (per the Overlay spec).
- `error-on-mixed-kind-match` — fail when an `update` action's `target` selects
  a mix of objects and arrays. Normative in Overlay 1.1; this opts 1.0 in.

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

# roas-action

GitHub Action that runs [`roas`](https://github.com/sv-tools/roas) to validate or
convert OpenAPI specifications (Swagger 2.0, OpenAPI 3.0.x / 3.1.x / 3.2.x), to
validate, convert, or apply [OpenAPI Overlay](https://spec.openapis.org/overlay/latest.html)
documents (Overlay 1.0 / 1.1), to validate, convert, list, or *run*
[OpenAPI Arazzo](https://spec.openapis.org/arazzo/latest.html) workflow
descriptions (Arazzo 1.0 / 1.1), and to validate or convert
[AsyncAPI](https://www.asyncapi.com/docs/reference) documents
(AsyncAPI 2.6 / 3.0 / 3.1).

The action is Docker-based and wraps the official
[`ghcr.io/sv-tools/roas`](https://github.com/sv-tools/roas/pkgs/container/roas)
image.

## Stability

From 1.0 the action's surface follows semver: the input names, the values
`subcommand` accepts, and the meaning of the exit codes do not change
incompatibly without a major bump. A new input, a new `subcommand` value, or a
new value an existing input accepts is a minor release. The action exits `2`
when its own inputs are wrong — an unknown `subcommand`, a missing `file`, a
`convert` without `to` — and otherwise passes `roas`'s exit code through
unchanged.

Not covered: the version of `roas` the image wraps, which is bumped by
automation in any release, patch ones included, so the wording of the
diagnostics and reports it prints can change under a pin to `@v1`.

Publishing a release moves the floating `v1` and `v1.0` tags to it, so
`sv-tools/roas-action@v1` tracks the latest 1.x. Pin a full
`sv-tools/roas-action@v1.0.0` where an exact `roas` build matters.

## Usage

### Validate

`openapi validate` is the default, so the subcommand can be left out:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    file: openapi.yaml
```

With external `$ref` loading and a few checks skipped:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: openapi validate
    file: openapi.yaml
    load: file http
    ignore: missing-tags unused-tags
```

### Convert

Upconvert a spec to OpenAPI 3.2 and write the result next to the source:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: openapi convert
    file: openapi.yaml
    to: v3.2
    output-file: openapi.v3_2.yaml
```

Layer additional specs on top of a base via `merge`:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: openapi convert
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
    subcommand: openapi convert
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

### Arazzo descriptions

Arazzo *describes* sequences of API calls. There is no transform/apply
step as there is for Overlay; instead the group reads a description
(`validate`, `convert`, `list`) and can carry it out (`run`). The version
is detected from the top-level `arazzo` field.

Validate an Arazzo workflow description:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: arazzo validate
    file: workflows/checkout.arazzo.yaml
```

Upconvert an Arazzo 1.0 description to Arazzo 1.1:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: arazzo convert
    file: workflows/checkout.arazzo.yaml
    to: v1.1
    output-file: checkout.v1_1.arazzo.yaml
```

See what a description offers, and what each workflow takes:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: arazzo list
    file: workflows/checkout.arazzo.yaml
```

#### Running a workflow

`arazzo run` is the one subcommand that talks to an API rather than
reading a document: it performs every step's request and reports what
happened. The description is validated first, and the step exits non-zero
when the workflow fails.

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: arazzo run
    file: workflows/checkout.arazzo.yaml
    workflow: buyPet
    load: file
    input: |
      petId=7
      note=a gift
    output-file: outputs.yaml
```

The run needs the source descriptions the steps name. Either point at
them directly with `source`, or let `load` fetch what the description
already points at — `load: file` for paths beside it, `load: http` for
remote URLs, exactly as on `openapi validate`.

`input` values are read as JSON where they are JSON, so `petId=7` is a
number and `petId=seven` a string; `inputs` takes a whole JSON or YAML
object, which `input` overrides per name.

`base-url` sends a source description's requests somewhere else — a
workflow written against production, run against a test server — and
`header` adds a header to every request a step does not set itself:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: arazzo run
    file: workflows/checkout.arazzo.yaml
    workflow: buyPet
    source: petStore=openapi.yaml
    base-url: petStore=http://127.0.0.1:8080
    header: |
      Authorization: Bearer ${{ secrets.API_TOKEN }}
    max-steps: '50'
```

The step-by-step report goes to stderr and the workflow's outputs to
stdout in the input's format, so `output-file` captures the outputs
alone; `quiet` silences the report and `output-format` overrides the
format. `max-steps` bounds a `goto` that loops.

### AsyncAPI documents

AsyncAPI describes event-driven APIs. Like Arazzo, the group is just
`validate` and `convert`; the version is detected from the top-level
`asyncapi` field (`2.6.x`, `3.0.x`, `3.1.x`).

Validate an AsyncAPI document:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: asyncapi validate
    file: events/streetlights.asyncapi.yaml
```

Unlike the other validate commands, this one takes `check` rather than
`ignore`, because one of its four values *adds* a check:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: asyncapi validate
    file: events/streetlights.asyncapi.yaml
    check: unused-channel-parameter external-reference
```

Upconvert an AsyncAPI 2.6 document to 3.0:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: asyncapi convert
    file: events/streetlights.asyncapi.yaml
    to: v3.0
    output-file: streetlights.v3_0.asyncapi.yaml
```

2.6 → 3.x is *lossy* — v3 reshaped the document, so channel keys have to
be invented and some things cannot be carried across. What the conversion
decided is reported on stderr (stdout stays the document alone, so
`output-file` is unaffected); `quiet` silences that report, and `strict`
turns any note into a failure with nothing written to stdout:

```yaml
- uses: sv-tools/roas-action@v1
  with:
    subcommand: asyncapi convert
    file: events/streetlights.asyncapi.yaml
    to: v3.1
    strict: 'true'
    output-file: streetlights.v3_1.asyncapi.yaml
```

3.0 → 3.1 and same-version conversions are lossless and report nothing.

## Inputs

"Applies to" abbreviations: **V** = `openapi validate`, **C** = `openapi convert`,
**OV** = `overlay validate`, **OC** = `overlay convert`, **OA** = `overlay apply`,
**AV** = `arazzo validate`, **AC** = `arazzo convert`, **AR** = `arazzo run`,
**AL** = `arazzo list`, **SV** = `asyncapi validate`, **SC** = `asyncapi convert`.

| Name            | Required | Default    | Applies to            | Description                                                                                                                          |
|-----------------|----------|------------|-----------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `subcommand`    | no       | `openapi validate` | —             | `openapi validate`, `openapi convert`, `overlay validate`, `overlay convert`, `overlay apply`, `arazzo validate`, `arazzo convert`, `arazzo run`, `arazzo list`, `asyncapi validate`, or `asyncapi convert`. The bare `validate` and `convert` still work — see [subcommand names](#subcommand-names). |
| `file`          | yes      | —          | all                   | Positional input: the spec (V, C, OA), the Overlay document (OV, OC), the Arazzo description (AV, AC, AR, AL), or the AsyncAPI document (SV, SC), relative to the repo root. |
| `from`          | no       | —          | V, C                  | Force the input spec version. One of `v2`, `v3.0`, `v3.1`, `v3.2`.                                                                   |
| `to`            | yes\*    | —          | C, OC, AC, SC         | Target version. For C: `v3.0`/`v3.1`/`v3.2` etc. For OC and AC: `v1.0`/`v1.1`. For SC: `v2.6`/`v3.0`/`v3.1`. Required for all four.   |
| `merge`         | no       | —          | C                     | Newline-separated list of specs to merge on top of the base after version conversion.                                                |
| `merge-options` | no       | —          | C                     | Whitespace-separated merge options (requires `merge`). See [merge options](#merge-options).                                          |
| `apply`         | no       | —          | C                     | Newline-separated Overlay documents to apply after merge (before collapse).                                                          |
| `overlay`       | yes\*    | —          | OA                    | Newline-separated Overlay documents to apply to the spec. Required when `subcommand: overlay apply`.                                 |
| `apply-options` | no       | —          | C, OA                 | Whitespace-separated overlay apply options. See [overlay apply options](#overlay-apply-options).                                     |
| `collapse`      | no       | `false`    | C                     | Lift inline components into the root bag and replace call sites with `$ref`s.                                                        |
| `workflow`      | yes\*    | —          | AR                    | The workflow to run. Required when the description offers more than one; `arazzo list` says what it offers.                          |
| `input`         | no       | —          | AR                    | Newline-separated workflow inputs as `NAME=VALUE`. Each value is read as JSON where it is JSON, as a string otherwise.               |
| `inputs`        | no       | —          | AR                    | Path to a JSON or YAML object of workflow inputs. Anything `input` names as well wins over it.                                       |
| `source`        | no       | —          | AR                    | Newline-separated source descriptions as `NAME=PATH`. Without this, `load` fetches what the description points at.                   |
| `base-url`      | no       | —          | AR                    | Newline-separated `NAME=URL` pairs sending that source description's requests elsewhere, whatever its own document says.             |
| `header`        | no       | —          | AR                    | Newline-separated `Name: value` headers added to every request a step does not set itself.                                           |
| `max-steps`     | no       | —          | AR                    | Stop the run after this many steps, in case a `goto` loops.                                                                          |
| `format`        | no       | auto       | all                   | Force input format: `json` or `yaml`. By default inferred from the file extension.                                                   |
| `load`          | no       | —          | V, C\*\*, AR          | Whitespace-separated loaders: `file`, `http`. On V/C they load `$ref`s (on `openapi convert` requires `collapse: true`); on AR they fetch the source descriptions. |
| `ignore`        | no       | —          | V, OV, AV, AR         | Whitespace-separated checks to skip. See [validation checks](#validation-checks).                                                    |
| `check`         | no       | —          | SV                    | Whitespace-separated checks to adjust. See [AsyncAPI checks](#asyncapi-checks).                                                      |
| `print`         | no       | `false`    | V, OV, AV, SV         | If `true`, echo the parsed spec/overlay/description/document on stdout (diagnostics stay on stderr).                                 |
| `strict`        | no       | `false`    | SC                    | If `true`, fail when the conversion had to invent a name or leave something behind. Nothing is written to stdout.                    |
| `quiet`         | no       | `false`    | SC, AR                | If `true`, do not print the report on stderr.                                                                                        |
| `output-format` | no       | match in   | C, OC, OA, AC, AR, SC | Force output format: `json` or `yaml`.                                                                                               |
| `output-file`   | no       | stdout     | all                   | Write command output to this path. If unset, output streams to the action log. On AR this is the workflow outputs, not the report.   |

### Validation checks

For `openapi validate`, values accepted by `ignore` (passed straight through
to `roas openapi validate --ignore`):

```
missing-tags, external-references, invalid-urls, non-uniq-operation-ids,
unused-path-items, unused-tags, unused-schemas, unused-parameters,
unused-responses, unused-server-variables, unused-examples,
unused-request-bodies, unused-headers, unused-security-schemes,
unused-links, unused-callbacks, unused-media-types,
empty-info-title, empty-info-version, empty-response-description,
empty-external-documentation-url
```

For `overlay validate`, `arazzo validate` and `arazzo run`, `ignore`
accepts only `empty-info-title` and `empty-info-version`. (`arazzo run`
validates the description before it makes any request.)

Run `roas openapi validate --help` (or `roas overlay validate --help` /
`roas arazzo validate --help`) for the description of each check.

### AsyncAPI checks

`asyncapi validate` takes `check` instead of `ignore` (passed straight
through as `roas asyncapi validate --check`), because one of the four
values adds a check rather than skipping one:

- `empty-info-title` — allow an empty `info.title` (still required to be present).
- `empty-info-version` — allow an empty `info.version` (still required to be present).
- `unused-channel-parameter` — allow a channel parameter that never appears as a
  `{placeholder}` in the channel's `address`.
- `external-reference` — **adds** a check: report any `$ref` pointing outside the
  document, requiring it to be self-contained. Off by default.

### Overlay apply options

Values accepted by `apply-options` (passed straight through as
`--apply-option`, for `openapi convert` with `apply` and for `overlay apply`):

- `error-on-zero-match` — fail when an action's `target` JSONPath selects zero
  nodes. By default a zero-match action is a no-op (per the Overlay spec).
- `error-on-mixed-kind-match` — fail when an `update` action's `target` selects
  a mix of objects and arrays. Normative in Overlay 1.1; this opts 1.0 in.

### Merge options

Values accepted by `merge-options` (passed straight through as
`roas openapi convert --merge-option`; defaults are "incoming wins" on scalar conflicts,
base retains `info`/`openapi`, refs replace silently, schemas are leaves):

- `base-wins` — reverse the default "incoming wins" policy.
- `error-on-conflict` — abort on the first real collision with a non-zero exit.
- `deep-merge-object-schemas` — deep-merge object schemas instead of leaf-replace.
- `merge-info` — allow `info`/`openapi`/`swagger` to merge instead of being preserved from base.
- `replace-lists-when-empty` — allow an empty incoming list (`servers`, `security`, …) to clear a populated base list.

### Subcommand names

roas 0.12 gave OpenAPI a subcommand group of its own, so `roas validate`
and `roas convert` became `roas openapi validate` and `roas openapi
convert` — every specification is now addressed the same way. This action
follows that naming, and still accepts the bare `validate` and `convert`
as aliases, so workflows written against earlier releases keep working
unchanged. New workflows should prefer the `openapi` spellings.

`roas openapi preview` renders a description in a browser and is not
wrapped by this action, having nowhere useful to open on a runner.

## How it works

The action's `Dockerfile` is a multi-stage build:

1. `FROM ghcr.io/sv-tools/roas:<version> AS src` pulls the upstream distroless
   image only as a source for the `roas` binary. The tag is pinned to an exact
   `roas` release and bumped by automation when a new one is published.
2. The final stage is `debian:trixie-slim` (Debian 13, GLIBC 2.41 — required
   because the upstream `roas` binary is linked against GLIBC ≥ 2.39) with
   `ca-certificates` installed so TLS can be validated when following remote
   `$ref`s (`--load http`) and when `arazzo run` calls an HTTPS API.
3. `entrypoint.sh` translates the action's `INPUT_*` env vars into the
   appropriate `roas` argv and `exec`s the binary.

GitHub builds this image the first time the action runs on a runner and caches
the layers for subsequent jobs.

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

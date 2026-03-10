# terranix-codegen

Generate [Terranix](https://terranix.org/) NixOS modules from Terraform provider schemas.

Terraform providers define hundreds or thousands of resources, each with a typed schema.
terranix-codegen reads those schemas and produces NixOS module files that give you
type-checked options for every resource, data source, and provider config block --
so you don't have to write them by hand.

## Usage

terranix-codegen uses [OpenTofu](https://opentofu.org/) by default. Pass `-t terraform` to use HashiCorp Terraform instead.

### Generate modules from provider specs

```bash
# Generate for one or more providers (fetches schemas via tofu automatically)
terranix-codegen generate -p aws -o ./providers
terranix-codegen generate -p hashicorp/aws:5.0.0 -p google -o ./providers

# Use Terraform instead of OpenTofu
terranix-codegen generate -p aws -t terraform -o ./providers
```

### Generate from an existing schema JSON file

```bash
# From file
terranix-codegen generate -i schema.json -o ./providers

# From stdin
tofu providers schema -json | terranix-codegen generate -o ./providers
```

### Inspect a provider schema

```bash
# Pretty-print to terminal (colorized)
terranix-codegen show -p aws

# Dump as JSON
terranix-codegen schema -p aws --pretty > schema.json
```

### Use the generated modules

```nix
# config.nix
{
  imports = [ ./providers/registry.terraform.io/hashicorp/aws ];

  resource.aws_instance.web = {
    ami = "ami-123456";
    instance_type = "t2.micro";
  };
}
```

### Output structure

```
providers/
├── default.nix
└── registry.terraform.io/
    └── hashicorp/
        └── aws/
            ├── default.nix
            ├── provider.nix
            ├── resources/
            │   ├── default.nix
            │   ├── instance.nix
            │   ├── vpc.nix
            │   └── ...
            └── data-sources/
                ├── default.nix
                ├── ami.nix
                └── ...
```

Each `default.nix` imports its siblings, so importing the provider directory pulls in everything.

## How it works

1. **Parse provider specs** -- `hashicorp/aws:5.0.0`, `aws`, etc. Namespace and version are optional.
1. **Run tofu/terraform** -- generates a minimal `.tf` config, runs `init` and `providers schema -json` in a temp directory.
1. **Parse the JSON schema** -- Terraform's type system ([go-cty](https://github.com/zclconf/go-cty)) is mapped to Haskell ADTs covering all type constructors (`string`, `number`, `bool`, `list(T)`, `set(T)`, `map(T)`, `object({...})`, `tuple([...])`, `dynamic`) and all 5 block nesting modes (`single`, `group`, `list`, `set`, `map`).
1. **Map types to Nix** -- `CtyString` becomes `types.str`, `CtyList CtyNumber` becomes `types.listOf types.number`, `CtyObject` becomes `types.submodule`, etc. Terraform tuples map to a custom [`types.tupleOf`](./nix/lib/tuple.nix) that validates length and per-position types.
1. **Build `mkOption` calls** -- each schema attribute becomes an `mkOption` with the mapped type, a default value (`null` for optional/computed attributes), description text, and metadata annotations (deprecated, sensitive, write-only, computed/read-only).
1. **Assemble modules** -- resources get `options.resource.<type>`, data sources get `options.data.<type>`, provider config gets `options.provider.<name>`. Nested blocks are handled recursively.
1. **Write files** -- one `.nix` file per resource/data source, plus `default.nix` files for imports, organized by provider.

All Nix code generation goes through [hnix](https://github.com/haskell-nix/hnix)'s AST and pretty-printer rather than string templates.

## Building

Requires [Nix with flakes](https://nixos.wiki/wiki/Flakes).

```bash
# Enter dev shell
nix develop

# Build
cabal build

# Run tests
cabal test --enable-tests

# Or build via Nix
nix build
```

## Not yet implemented

- `--providers-file` flag (load provider specs from a JSON file)
- Documentation generation (mdBook output for generated modules)
- Resource/provider filtering
- Pre-built module sets for common providers

## License

[MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/)

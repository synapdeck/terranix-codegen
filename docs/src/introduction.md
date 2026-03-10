# Introduction

terranix-codegen generates [Terranix](https://terranix.org/) NixOS modules from Terraform provider schemas.

## What it does

Terranix lets you write Terraform configurations in Nix instead of HCL:

```nix
{
  resource.aws_instance.web = {
    ami = "ami-123456";
    instance_type = "t2.micro";
  };
}
```

This works, but every attribute is essentially untyped -- Terranix accepts any attrset and passes it through to the Terraform JSON. You get no feedback from the NixOS module system about typos, wrong types, or missing required fields.

terranix-codegen fixes this by reading the Terraform provider schema (which defines every resource, every attribute, and every type) and generating NixOS module `options` declarations that match the exact structure Terranix already expects. You import the generated modules alongside your config and you get type checking, tab completion, and documentation for free -- without changing how you write your Terranix code.

## Usage

```bash
# Generate modules directly from provider specs (uses OpenTofu by default)
terranix-codegen generate -p aws -o ./providers
terranix-codegen generate -p hashicorp/aws:5.0.0 -p google -o ./providers

# Or from an existing schema JSON
tofu providers schema -json | terranix-codegen generate -o ./providers

# Inspect a provider schema
terranix-codegen show -p aws

# Dump schema as JSON
terranix-codegen schema -p aws --pretty
```

Pass `-t terraform` to use HashiCorp Terraform instead of OpenTofu.

Then import the generated modules in your Terranix config:

```nix
{
  imports = [ ./providers/registry.terraform.io/hashicorp/aws ];

  resource.aws_instance.web = {
    ami = "ami-123456";
    instance_type = "t2.micro";
  };
}
```

The generated modules only declare `options` -- they don't change the attrset structure or rename anything. Your existing Terranix configs work as before, but now with type checking.

## Output structure

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
            │   └── ...
            └── data-sources/
                ├── default.nix
                ├── ami.nix
                └── ...
```

Each `default.nix` imports its siblings. You can import a whole provider or individual resource files.

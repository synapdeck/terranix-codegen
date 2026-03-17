# Nix Generator Wrapper Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose terranix-codegen's code generation as Nix derivation-producing functions under `packages.${system}.generators`, following the nixidy pattern.

**Architecture:** Standalone `nix/generators/default.nix` provides `generateFromSchema` and `generateProvider` functions. A thin flake-parts module wires them into `packages.${system}.generators`. The CLI's existing `-p` and `-t` flags handle provider schema extraction internally.

**Tech Stack:** Nix, flake-parts, nix-unit (testing)

**Spec:** `docs/superpowers/specs/2026-03-17-nix-generators-design.md`

______________________________________________________________________

### Task 1: Create `generateFromSchema`

**Files:**

- Create: `nix/generators/default.nix`

- [ ] **Step 1: Create `nix/generators/default.nix` with `generateFromSchema`**

```nix
{
  pkgs,
  terranix-codegen,
}: {
  generateFromSchema = {
    schema,
    outputDir ? "providers",
  }:
    pkgs.stdenv.mkDerivation {
      name = "terranix-generated-modules";
      dontUnpack = true;
      dontInstall = true;
      nativeBuildInputs = [terranix-codegen];
      buildPhase = ''
        mkdir -p $out/${outputDir}
        terranix-codegen generate -i ${schema} -o $out/${outputDir}
      '';
    };

  generateProvider = throw "not yet implemented";
}
```

- [ ] **Step 2: Commit**

```bash
git add nix/generators/default.nix
git commit -m "feat(nix): add generateFromSchema generator function"
```

______________________________________________________________________

### Task 2: Create `generateProvider`

**Files:**

- Modify: `nix/generators/default.nix`

- [ ] **Step 1: Implement `generateProvider` with both paths**

Replace the `generateProvider = throw ...` stub with:

```nix
generateProvider = {
  provider,
  pluginDrv ? null,
  terraform ? null,
  tofu ? pkgs.opentofu,
  outputDir ? "providers",
}: let
  usePlugin = pluginDrv != null;
  terraformWithPlugin = assert pkgs.lib.assertMsg (terraform != null)
    "generateProvider: terraform must be provided when pluginDrv is set";
    terraform.withPlugins (_: [pluginDrv]);
  tfExecutable =
    if usePlugin
    then terraformWithPlugin
    else tofu;
  tfName =
    if usePlugin
    then "terraform"
    else builtins.baseNameOf (pkgs.lib.getExe tfExecutable);
in
  pkgs.stdenv.mkDerivation {
    name = "terranix-generated-modules";
    dontUnpack = true;
    dontInstall = true;
    nativeBuildInputs = [terranix-codegen tfExecutable];
    buildPhase = ''
      export HOME=$(mktemp -d)
      mkdir -p $out/${outputDir}
      terranix-codegen generate -p ${provider} -t ${tfName} -o $out/${outputDir}
    '';
  };
```

Key details:

- `lib.assertMsg` provides a clear error message when `pluginDrv` is set without `terraform`

- `terraformWithPlugin` is only evaluated when `usePlugin` is true (Nix is lazy), so the assert only fires when needed

- `HOME` is set to a temp dir because terraform/tofu may try to write to `$HOME`

- `-t ${tfName}` passes `"terraform"` when using `withPlugins`, or the actual binary name via `lib.getExe` otherwise (e.g. `pkgs.opentofu` installs as `tofu`, not `opentofu`)

- `dontInstall = true` prevents the default install phase from running `make install`

- [ ] **Step 2: Commit**

```bash
git add nix/generators/default.nix
git commit -m "feat(nix): add generateProvider with tofu and plugin derivation paths"
```

______________________________________________________________________

### Task 3: Wire into flake

**Files:**

- Create: `nix/flake/generators.nix`

- Modify: `nix/flake/default.nix`

- [ ] **Step 1: Create `nix/flake/generators.nix`**

```nix
{...}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.generators = import ../generators {
      inherit pkgs;
      terranix-codegen = self'.packages.terranix-codegen;
    };
  };
}
```

- [ ] **Step 2: Add import to `nix/flake/default.nix`**

Add `./generators.nix` to the imports list:

```nix
{
  imports = [
    ./ci
    ./devshell.nix
    ./docs.nix
    ./generators.nix
    ./haskell.nix
    ./lib.nix
    ./nix-unit.nix
    ./treefmt.nix
  ];
}
```

- [ ] **Step 3: Verify flake evaluates**

Run: `nix flake check --no-build`

Expected: No evaluation errors.

- [ ] **Step 4: Commit**

```bash
git add nix/flake/generators.nix nix/flake/default.nix
git commit -m "feat(nix): wire generators into packages.generators via flake-parts"
```

______________________________________________________________________

### Task 4: Add nix-unit tests

**Files:**

- Create: `nix/generators/generators.test.nix`
- Modify: `nix/flake/nix-unit.nix`

The existing nix-unit setup autodiscovers `*.test.nix` files in `nix/lib/` and imports them with `{lib}`. Generator tests need `{pkgs, terranix-codegen}` (per-system), so they must be wired separately in the `perSystem` block.

- [ ] **Step 1: Write generator tests**

Create `nix/generators/generators.test.nix`:

```nix
{
  pkgs,
  terranix-codegen,
}: let
  generators = import ./default.nix {inherit pkgs terranix-codegen;};
  dummySchema = builtins.toFile "empty-schema.json" "{}";
in {
  generators = {
    generateFromSchema = {
      testProducesDerivation = {
        expr = (generators.generateFromSchema {schema = dummySchema;}).type or null;
        expected = "derivation";
      };

      testDerivationName = {
        expr = (generators.generateFromSchema {schema = dummySchema;}).name;
        expected = "terranix-generated-modules";
      };

      testCustomOutputDir = {
        expr =
          (generators.generateFromSchema {
            schema = dummySchema;
            outputDir = "custom";
          })
          .name;
        expected = "terranix-generated-modules";
      };
    };

    generateProvider = {
      testProducesDerivation = {
        expr =
          (generators.generateProvider {
            provider = "hashicorp/null:3.2.0";
          })
          .type or null;
        expected = "derivation";
      };

      testDerivationName = {
        expr =
          (generators.generateProvider {
            provider = "hashicorp/null:3.2.0";
          })
          .name;
        expected = "terranix-generated-modules";
      };

      testRequiresTerraformWithPlugin = {
        expr =
          !(builtins.tryEval (
            builtins.deepSeq
            (generators.generateProvider {
              provider = "hashicorp/null:3.2.0";
              pluginDrv = builtins.toFile "fake-plugin" "";
            })
            true
          ))
          .success;
        expected = true;
      };
    };
  };
}
```

Tests use `builtins.toFile` for dummy inputs (available in all nixpkgs). Tests check `.type` (which is `"derivation"` for all derivations) and `.name` rather than comparing full derivation attrsets.

- [ ] **Step 2: Update `nix/flake/nix-unit.nix` to discover generator tests**

Replace the contents of `nix/flake/nix-unit.nix` with:

```nix
{
  inputs,
  lib,
  ...
}: let
  # Autodiscover all .test.nix files in the lib directory
  libTestFiles = builtins.filter (name: lib.hasSuffix ".test.nix" name) (
    builtins.attrNames (builtins.readDir ../lib)
  );

  # Import and merge all lib test files (system-agnostic, take {lib})
  importLibTests = file: import (../lib + "/${file}") {inherit lib;};
  libTests = lib.foldl' (acc: file: acc // importLibTests file) {} libTestFiles;

  # Autodiscover all .test.nix files in the generators directory
  generatorTestFiles = builtins.filter (name: lib.hasSuffix ".test.nix" name) (
    builtins.attrNames (builtins.readDir ../generators)
  );
in {
  imports = [
    inputs.nix-unit.modules.flake.default
  ];

  perSystem = {
    pkgs,
    self',
    system,
    ...
  }: {
    nix-unit.inputs = let
      sanitizeInput = input:
        if builtins.isAttrs input && input ? outPath
        then input.outPath
        else input;
    in
      builtins.mapAttrs (_: sanitizeInput) (builtins.removeAttrs inputs ["self"]);

    devshells.default = {
      commands = [
        {
          name = "nix-test";
          help = "Run `nix-unit` tests";
          command = "nix-unit --flake .#tests.systems.${system}";
        }
      ];

      packages = with pkgs; [
        nix-unit
      ];
    };
  };

  # All tests live under tests.systems.<system> so the nix-test devshell
  # command (`nix-unit --flake .#tests.systems.${system}`) covers everything.
  # Lib tests are pure Nix and evaluate identically under any system.
  flake.tests = let
    importGenTests = pkgs: terranix-codegen:
      lib.foldl' (acc: file:
        acc // import (../generators + "/${file}") {
          inherit pkgs terranix-codegen;
        }
      ) {} generatorTestFiles;
  in {
    systems = lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed (system:
      libTests
      // importGenTests
        inputs.nixpkgs.legacyPackages.${system}
        inputs.self.packages.${system}.terranix-codegen
    );
  };
}
```

Both lib tests and generator tests are merged into each `tests.systems.<system>` attrset. The `nix-unit --flake .#tests.systems.x86_64-linux` command covers all tests in a single invocation.

- [ ] **Step 3: Run nix-unit tests**

Run: `nix-unit --flake .#tests.systems.x86_64-linux`

Expected: All tests pass, including the new generator tests.

- [ ] **Step 4: Commit**

```bash
git add nix/generators/generators.test.nix nix/flake/nix-unit.nix
git commit -m "test(nix): add nix-unit tests for generator functions"
```

______________________________________________________________________

### Task 5: Verify end-to-end with `generateFromSchema`

This task verifies the full pipeline works by building a derivation with a real schema file.

**Files:**

- None created/modified — this is a manual verification step

- [ ] **Step 1: Generate a test schema JSON**

Run: `nix develop -c terranix-codegen schema -p hashicorp/null:3.2.0 --pretty > /tmp/null-schema.json`

This produces a small schema JSON for the null provider (minimal, fast).

- [ ] **Step 2: Build with `generateFromSchema`**

Run:

```bash
nix build --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import <nixpkgs> {};
  in
    flake.packages.${builtins.currentSystem}.generators.generateFromSchema {
      schema = /tmp/null-schema.json;
    }
'
```

Expected: `./result/providers/` contains generated Nix modules for the null provider.

- [ ] **Step 3: Verify output**

Run: `ls result/providers/` and `head result/providers/default.nix`

Expected: A valid Nix module directory tree with `default.nix` and provider-specific files.

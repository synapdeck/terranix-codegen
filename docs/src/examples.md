# Transformation Examples

Each example shows a Terraform provider schema fragment and the NixOS module that terranix-codegen generates from it.

## Simple attributes

Schema:

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "name": {
        "type": "string",
        "description": "The name of the resource",
        "required": true
      },
      "enabled": {
        "type": "bool",
        "description": "Whether the resource is enabled",
        "optional": true
      },
      "count": {
        "type": "number",
        "description": "Number of instances",
        "optional": true
      }
    }
  }
}
```

Generated module:

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_simple = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        name = mkOption {
          type = types.str;
          description = "The name of the resource";
        };
        enabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Whether the resource is enabled";
        };
        count = mkOption {
          type = types.nullOr types.number;
          default = null;
          description = "Number of instances";
        };
      };
    });
    default = {};
    description = "Instances of example_simple";
  };
}
```

Usage in Terranix:

```nix
{
  resource.example_simple.my_instance = {
    name = "production";
    enabled = true;
    count = 3;
  };
}
```

The outer `types.attrsOf` is what makes the instance name (`my_instance`) work as a key.

## Collections

Schema:

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "availability_zones": {
        "type": ["list", "string"],
        "required": true
      },
      "tags": {
        "type": ["map", "string"],
        "optional": true
      },
      "security_group_ids": {
        "type": ["set", "string"],
        "optional": true
      }
    }
  }
}
```

Generated module:

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_collections = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        availability_zones = mkOption {
          type = types.listOf types.str;
        };
        tags = mkOption {
          type = types.nullOr (types.attrsOf types.str);
          default = null;
        };
        security_group_ids = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
        };
      };
    });
    default = {};
    description = "Instances of example_collections";
  };
}
```

Note that `set(string)` maps to `types.listOf types.str` -- Nix doesn't have a set type.

## Objects

Schema with a sensitive object attribute:

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "connection_info": {
        "type": ["object", {
          "host": "string",
          "port": "number",
          "username": "string",
          "password": "string"
        }],
        "description": "Database connection information",
        "required": true,
        "sensitive": true
      }
    }
  }
}
```

Generated module:

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_object = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        connection_info = mkOption {
          type = types.submodule {
            options = {
              host = mkOption { type = types.str; };
              port = mkOption { type = types.number; };
              username = mkOption { type = types.str; };
              password = mkOption { type = types.str; };
            };
          };
          description = ''
            Database connection information

            NOTE: This attribute contains sensitive data.
          '';
        };
      };
    });
    default = {};
    description = "Instances of example_object";
  };
}
```

The `sensitive` flag becomes a note in the description.

## Nested blocks (single)

Schema with a single-nesting block:

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "name": { "type": "string", "required": true }
    },
    "block_types": {
      "network_config": {
        "nesting_mode": "single",
        "block": {
          "attributes": {
            "subnet_id": { "type": "string", "required": true },
            "private_ip": { "type": "string", "optional": true, "computed": true }
          }
        }
      }
    }
  }
}
```

Generated module:

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_nested_single = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        name = mkOption { type = types.str; };
        network_config = mkOption {
          type = types.submodule {
            options = {
              subnet_id = mkOption { type = types.str; };
              private_ip = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
            };
          };
          default = null;
        };
      };
    });
    default = {};
    description = "Instances of example_nested_single";
  };
}
```

`nesting_mode: "single"` produces a bare `types.submodule` with `default = null`.

## Nested blocks (list)

Schema with a list-nesting block:

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "name": { "type": "string", "required": true }
    },
    "block_types": {
      "ingress": {
        "nesting_mode": "list",
        "block": {
          "attributes": {
            "from_port": { "type": "number", "required": true },
            "to_port": { "type": "number", "required": true },
            "protocol": { "type": "string", "required": true },
            "cidr_blocks": { "type": ["list", "string"], "optional": true }
          }
        }
      }
    }
  }
}
```

Generated module:

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_nested_list = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        name = mkOption { type = types.str; };
        ingress = mkOption {
          type = types.listOf (types.submodule {
            options = {
              from_port = mkOption { type = types.number; };
              to_port = mkOption { type = types.number; };
              protocol = mkOption { type = types.str; };
              cidr_blocks = mkOption {
                type = types.nullOr (types.listOf types.str);
                default = null;
              };
            };
          });
          default = [];
        };
      };
    });
    default = {};
    description = "Instances of example_nested_list";
  };
}
```

Usage:

```nix
{
  resource.example_nested_list.my_sg = {
    name = "web-sg";
    ingress = [
      { from_port = 80; to_port = 80; protocol = "tcp"; cidr_blocks = [ "0.0.0.0/0" ]; }
      { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = [ "0.0.0.0/0" ]; }
    ];
  };
}
```

## Nested blocks (map)

Schema with a map-nesting block:

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "bucket": { "type": "string", "required": true }
    },
    "block_types": {
      "lifecycle_rule": {
        "nesting_mode": "map",
        "block": {
          "attributes": {
            "enabled": { "type": "bool", "required": true },
            "prefix": { "type": "string", "optional": true },
            "expiration_days": { "type": "number", "optional": true }
          }
        }
      }
    }
  }
}
```

Generated module:

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_nested_map = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        bucket = mkOption { type = types.str; };
        lifecycle_rule = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              enabled = mkOption { type = types.bool; };
              prefix = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              expiration_days = mkOption {
                type = types.nullOr types.number;
                default = null;
              };
            };
          });
          default = {};
        };
      };
    });
    default = {};
    description = "Instances of example_nested_map";
  };
}
```

Usage:

```nix
{
  resource.example_nested_map.my_bucket = {
    bucket = "my-data-bucket";
    lifecycle_rule = {
      delete_old_logs = {
        enabled = true;
        prefix = "logs/";
        expiration_days = 30;
      };
      archive_backups = {
        enabled = true;
        prefix = "backups/";
        expiration_days = 90;
      };
    };
  };
}
```

## Computed and deprecated attributes

Schema with metadata flags:

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "ami": { "type": "string", "required": true, "description": "AMI to use" },
      "id": { "type": "string", "computed": true, "description": "Instance ID" },
      "availability_zone": { "type": "string", "optional": true, "deprecated": true }
    }
  }
}
```

Generated module:

```nix
{ lib, ... }:
with lib;
{
  options.resource.aws_instance = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        ami = mkOption {
          type = types.str;
          description = "AMI to use";
        };
        id = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Instance ID

            This value is computed by the provider.
          '';
          readOnly = true;
        };
        availability_zone = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            DEPRECATED: This attribute is deprecated and may be removed in a future version.
          '';
        };
      };
    });
    default = {};
    description = "Instances of aws_instance";
  };
}
```

Computed-only attributes get `readOnly = true`. Deprecated, sensitive, and write-only attributes get notes appended to their description.

## Transformation summary

| Terraform pattern | Nix type |
|-------------------|----------|
| Required primitive | `types.<primitive>` |
| Optional/computed primitive | `types.nullOr types.<primitive>` |
| Computed-only | `types.nullOr T` + `readOnly = true` |
| `list(T)` / `set(T)` | `types.listOf (mapType T)` |
| `map(T)` | `types.attrsOf (mapType T)` |
| `object({...})` | `types.submodule { options = {...}; }` |
| `tuple([...])` | `types.tupleOf [...]` |
| Block, single nesting | `types.submodule { ... }`, default `null` |
| Block, group nesting | `types.submodule { ... }`, no default |
| Block, list nesting | `types.listOf (types.submodule { ... })`, default `[]` |
| Block, set nesting | `types.listOf (types.submodule { ... })`, default `[]` |
| Block, map nesting | `types.attrsOf (types.submodule { ... })`, default `{}` |
| Deprecated | Note in description |
| Sensitive | Note in description |
| Write-only | Note in description |

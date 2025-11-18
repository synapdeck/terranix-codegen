# Transformation Examples

This document provides concrete examples of how Terraform provider schemas are transformed into Terranix modules. Each example shows:

1. **HCL Usage** - How the resource is used in native Terraform
2. **Provider Schema** - The JSON schema that describes the resource
3. **Generated Terranix Module** - The Nix module generated from the schema
4. **Terranix Usage** - How to use the generated module in Terranix

## Example 1: Simple Attributes (Primitives)

### Terraform HCL Usage

```hcl
resource "example_simple" "my_instance" {
  name    = "production"
  enabled = true
  count   = 3
}
```

### Provider Schema (JSON)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "name": {
        "type": "string",
        "description": "The name of the resource",
        "description_kind": "plain",
        "required": true
      },
      "enabled": {
        "type": "bool",
        "description": "Whether the resource is enabled",
        "description_kind": "plain",
        "optional": true
      },
      "count": {
        "type": "number",
        "description": "Number of instances",
        "description_kind": "plain",
        "optional": true
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_simple.instance = mkOption {
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

### Terranix Usage

```nix
{
  resource.example_simple.my_instance = {
    name = "production";
    enabled = true;
    count = 3;
  };
}
```

## Example 2: Collection Types (Lists and Maps)

### Terraform HCL Usage

```hcl
resource "example_collections" "my_instance" {
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "production"
    Team        = "platform"
  }

  security_group_ids = ["sg-123456", "sg-789012"]
}
```

### Provider Schema (JSON)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "availability_zones": {
        "type": ["list", "string"],
        "description": "List of availability zones",
        "description_kind": "plain",
        "required": true
      },
      "tags": {
        "type": ["map", "string"],
        "description": "Key-value tags",
        "description_kind": "plain",
        "optional": true
      },
      "security_group_ids": {
        "type": ["set", "string"],
        "description": "Set of security group IDs",
        "description_kind": "plain",
        "optional": true
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_collections.instance = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        availability_zones = mkOption {
          type = types.listOf types.str;
          description = "List of availability zones";
        };

        tags = mkOption {
          type = types.nullOr (types.attrsOf types.str);
          default = null;
          description = "Key-value tags";
        };

        security_group_ids = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          description = "Set of security group IDs";
        };
      };
    });
    default = {};
    description = "Instances of example_collections";
  };
}
```

### Terranix Usage

```nix
{
  resource.example_collections.my_instance = {
    availability_zones = [ "us-east-1a" "us-east-1b" "us-east-1c" ];
    tags = {
      Environment = "production";
      Team = "platform";
    };
    security_group_ids = [ "sg-123456" "sg-789012" ];
  };
}
```

## Example 3: Object Types

### Terraform HCL Usage

```hcl
resource "example_object" "my_instance" {
  connection_info = {
    host     = "db.example.com"
    port     = 5432
    username = "admin"
    password = "secret123"  # Consider using secrets management!
  }
}
```

### Provider Schema (JSON)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "connection_info": {
        "type": [
          "object",
          {
            "host": "string",
            "port": "number",
            "username": "string",
            "password": "string"
          }
        ],
        "description": "Database connection information",
        "description_kind": "plain",
        "required": true,
        "sensitive": true
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_object.instance = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        connection_info = mkOption {
          type = types.submodule {
            options = {
              host = mkOption {
                type = types.str;
              };

              port = mkOption {
                type = types.number;
              };

              username = mkOption {
                type = types.str;
              };

              password = mkOption {
                type = types.str;
              };
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

### Terranix Usage

```nix
{
  resource.example_object.my_instance = {
    connection_info = {
      host = "db.example.com";
      port = 5432;
      username = "admin";
      password = "secret123";  # Consider using secrets management!
    };
  };
}
```

## Example 4: Nested Blocks (NestingSingle)

### Terraform HCL Usage

```hcl
resource "example_nested_single" "my_instance" {
  name = "web-server"

  network_config {
    subnet_id = "subnet-123456"
    # private_ip is optional and will be computed if not specified
  }
}
```

### Provider Schema (JSON)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "name": {
        "type": "string",
        "description": "Instance name",
        "required": true
      }
    },
    "block_types": {
      "network_config": {
        "nesting_mode": "single",
        "block": {
          "attributes": {
            "subnet_id": {
              "type": "string",
              "description": "Subnet ID",
              "required": true
            },
            "private_ip": {
              "type": "string",
              "description": "Private IP address",
              "optional": true,
              "computed": true
            }
          }
        }
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_nested_single.instance = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        name = mkOption {
          type = types.str;
          description = "Instance name";
        };

        network_config = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              subnet_id = mkOption {
                type = types.str;
                description = "Subnet ID";
              };

              private_ip = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Private IP address (computed if not provided)";
              };
            };
          });
          default = null;
        };
      };
    });
    default = {};
    description = "Instances of example_nested_single";
  };
}
```

### Terranix Usage

```nix
{
  resource.example_nested_single.my_instance = {
    name = "web-server";
    network_config = {
      subnet_id = "subnet-123456";
      # private_ip is optional and will be computed if not specified
    };
  };
}
```

## Example 5: Nested Blocks (NestingList)

### Terraform HCL Usage

```hcl
resource "example_nested_list" "security_group" {
  name = "web-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Provider Schema (JSON)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "name": {
        "type": "string",
        "required": true
      }
    },
    "block_types": {
      "ingress": {
        "nesting_mode": "list",
        "block": {
          "attributes": {
            "from_port": {
              "type": "number",
              "required": true
            },
            "to_port": {
              "type": "number",
              "required": true
            },
            "protocol": {
              "type": "string",
              "required": true
            },
            "cidr_blocks": {
              "type": ["list", "string"],
              "optional": true
            }
          }
        },
        "min_items": 1
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_nested_list.instance = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        name = mkOption {
          type = types.str;
        };

        ingress = mkOption {
          type = types.listOf (types.submodule {
            options = {
              from_port = mkOption {
                type = types.number;
              };

              to_port = mkOption {
                type = types.number;
              };

              protocol = mkOption {
                type = types.str;
              };

              cidr_blocks = mkOption {
                type = types.nullOr (types.listOf types.str);
                default = null;
              };
            };
          });
          # TODO: Add assertion for min_items = 1
        };
      };
    });
    default = {};
    description = "Instances of example_nested_list";
  };
}
```

### Terranix Usage

```nix
{
  resource.example_nested_list.security_group = {
    name = "web-sg";
    ingress = [
      {
        from_port = 80;
        to_port = 80;
        protocol = "tcp";
        cidr_blocks = [ "0.0.0.0/0" ];
      }
      {
        from_port = 443;
        to_port = 443;
        protocol = "tcp";
        cidr_blocks = [ "0.0.0.0/0" ];
      }
    ];
  };
}
```

## Example 6: Nested Blocks (NestingMap)

### Terraform HCL Usage

```hcl
resource "example_nested_map" "my_bucket" {
  bucket = "my-data-bucket"

  lifecycle_rule "delete_old_logs" {
    enabled         = true
    prefix          = "logs/"
    expiration_days = 30
  }

  lifecycle_rule "archive_backups" {
    enabled         = true
    prefix          = "backups/"
    expiration_days = 90
  }
}
```

### Provider Schema (JSON)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "bucket": {
        "type": "string",
        "required": true
      }
    },
    "block_types": {
      "lifecycle_rule": {
        "nesting_mode": "map",
        "block": {
          "attributes": {
            "enabled": {
              "type": "bool",
              "required": true
            },
            "prefix": {
              "type": "string",
              "optional": true
            },
            "expiration_days": {
              "type": "number",
              "optional": true
            }
          }
        }
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_nested_map.instance = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        bucket = mkOption {
          type = types.str;
        };

        lifecycle_rule = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              enabled = mkOption {
                type = types.bool;
              };

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

### Terranix Usage

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

## Example 7: Deprecated and Optional Attributes

### Terraform HCL Usage

```hcl
resource "example_deprecated" "my_instance" {
  name          = "web-server"
  instance_type = "t2.micro"

  # Don't use deprecated field:
  # availability_zone = "us-east-1a"  # DEPRECATED

  # Use new structure instead:
  placement {
    availability_zone = "us-east-1a"
    tenancy           = "default"
  }
}
```

### Provider Schema (JSON)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "name": {
        "type": "string",
        "required": true
      },
      "instance_type": {
        "type": "string",
        "optional": true
      },
      "availability_zone": {
        "type": "string",
        "optional": true,
        "deprecated": true
      },
      "placement": {
        "type": ["object", {
          "availability_zone": "string",
          "tenancy": "string"
        }],
        "optional": true
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.example_deprecated.instance = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        name = mkOption {
          type = types.str;
        };

        instance_type = mkOption {
          type = types.nullOr types.str;
          default = null;
        };

        availability_zone = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            DEPRECATED: Use placement.availability_zone instead.
          '';
        };

        placement = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              availability_zone = mkOption {
                type = types.str;
              };

              tenancy = mkOption {
                type = types.str;
              };
            };
          });
          default = null;
        };
      };
    });
    default = {};
    description = "Instances of example_deprecated";
  };
}
```

### Terranix Usage

```nix
{
  resource.example_deprecated.my_instance = {
    name = "web-server";
    instance_type = "t2.micro";

    # Don't use deprecated field:
    # availability_zone = "us-east-1a";  # DEPRECATED

    # Use new structure instead:
    placement = {
      availability_zone = "us-east-1a";
      tenancy = "default";
    };
  };
}
```

## Example 8: Complete Real-World Example (AWS EC2 Instance)

### Terraform HCL Usage

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = "subnet-12345678"
  key_name      = "my-key-pair"

  vpc_security_group_ids = ["sg-12345678"]

  tags = {
    Name        = "Web Server"
    Environment = "production"
    ManagedBy   = "terraform"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"
  subnet_id     = "subnet-87654321"
  key_name      = "my-key-pair"

  tags = {
    Name        = "App Server"
    Environment = "production"
  }
}
```

### Provider Schema (Simplified AWS EC2)

```json
{
  "version": 0,
  "block": {
    "attributes": {
      "ami": {
        "type": "string",
        "description": "AMI to use for the instance",
        "required": true
      },
      "instance_type": {
        "type": "string",
        "description": "Instance type",
        "required": true
      },
      "availability_zone": {
        "type": "string",
        "description": "AZ to launch in",
        "optional": true,
        "computed": true
      },
      "subnet_id": {
        "type": "string",
        "optional": true
      },
      "vpc_security_group_ids": {
        "type": ["set", "string"],
        "optional": true,
        "computed": true
      },
      "key_name": {
        "type": "string",
        "optional": true
      },
      "tags": {
        "type": ["map", "string"],
        "optional": true
      },
      "id": {
        "type": "string",
        "description": "Instance ID",
        "computed": true
      },
      "public_ip": {
        "type": "string",
        "description": "Public IP address",
        "computed": true
      }
    },
    "block_types": {
      "ebs_block_device": {
        "nesting_mode": "list",
        "block": {
          "attributes": {
            "device_name": {
              "type": "string",
              "required": true
            },
            "volume_size": {
              "type": "number",
              "optional": true
            },
            "volume_type": {
              "type": "string",
              "optional": true
            },
            "encrypted": {
              "type": "bool",
              "optional": true
            }
          }
        }
      },
      "root_block_device": {
        "nesting_mode": "single",
        "block": {
          "attributes": {
            "volume_size": {
              "type": "number",
              "optional": true
            },
            "volume_type": {
              "type": "string",
              "optional": true
            },
            "delete_on_termination": {
              "type": "bool",
              "optional": true
            }
          }
        }
      }
    }
  }
}
```

### Generated Terranix Module (Nix)

```nix
{ lib, ... }:
with lib;
{
  options.resource.aws_instance.instance = mkOption {
    type = types.attrsOf (types.submodule ({ config, ... }: {
      options = {
        ami = mkOption {
          type = types.str;
          description = "AMI to use for the instance";
        };

        instance_type = mkOption {
          type = types.str;
          description = "Instance type";
        };

        availability_zone = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "AZ to launch in (computed if not provided)";
        };

        subnet_id = mkOption {
          type = types.nullOr types.str;
          default = null;
        };

        vpc_security_group_ids = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
        };

        key_name = mkOption {
          type = types.nullOr types.str;
          default = null;
        };

        tags = mkOption {
          type = types.nullOr (types.attrsOf types.str);
          default = null;
        };

        id = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Instance ID (computed)";
          readOnly = true;
        };

        public_ip = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Public IP address (computed)";
          readOnly = true;
        };

        ebs_block_device = mkOption {
          type = types.listOf (types.submodule {
            options = {
              device_name = mkOption {
                type = types.str;
              };

              volume_size = mkOption {
                type = types.nullOr types.number;
                default = null;
              };

              volume_type = mkOption {
                type = types.nullOr types.str;
                default = null;
              };

              encrypted = mkOption {
                type = types.nullOr types.bool;
                default = null;
              };
            };
          });
          default = [];
        };

        root_block_device = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              volume_size = mkOption {
                type = types.nullOr types.number;
                default = null;
              };

              volume_type = mkOption {
                type = types.nullOr types.str;
                default = null;
              };

              delete_on_termination = mkOption {
                type = types.nullOr types.bool;
                default = null;
              };
            };
          });
          default = null;
        };
      };
    }));
    default = {};
    description = "AWS EC2 instances";
  };
}
```

### Terranix Usage

```nix
{
  resource.aws_instance = {
    web_server = {
      ami = "ami-0c55b159cbfafe1f0";
      instance_type = "t2.micro";
      subnet_id = "subnet-12345678";
      vpc_security_group_ids = [ "sg-12345678" ];
      key_name = "my-key-pair";

      tags = {
        Name = "Web Server";
        Environment = "production";
        ManagedBy = "terranix";
      };

      root_block_device = {
        volume_size = 20;
        volume_type = "gp3";
        delete_on_termination = true;
      };

      ebs_block_device = [
        {
          device_name = "/dev/sdf";
          volume_size = 100;
          volume_type = "gp3";
          encrypted = true;
        }
      ];
    };

    app_server = {
      ami = "ami-0c55b159cbfafe1f0";
      instance_type = "t3.medium";
      subnet_id = "subnet-87654321";
      key_name = "my-key-pair";

      tags = {
        Name = "App Server";
        Environment = "production";
      };
    };
  };
}
```

## Summary of Transformations

| Terraform Pattern | Nix Pattern |
|-------------------|-------------|
| Required primitive | `mkOption { type = types.<primitive>; }` |
| Optional primitive | `mkOption { type = types.nullOr types.<primitive>; default = null; }` |
| Computed | Add `readOnly = true;` if not settable |
| List/Set of T | `types.listOf (mapType T)` |
| Map of T | `types.attrsOf (mapType T)` |
| Object | `types.submodule { options = { ... }; }` |
| NestingSingle block | `types.nullOr (types.submodule { ... })` |
| NestingList block | `types.listOf (types.submodule { ... })` |
| NestingMap block | `types.attrsOf (types.submodule { ... })` |
| Deprecated | Add deprecation note to description |
| Sensitive | Add warning note to description |
| Min/Max items | Add validation assertions (future enhancement) |

These examples demonstrate the systematic transformation of Terraform provider schemas into well-typed, self-documenting Terranix modules that leverage the full power of the NixOS module system.

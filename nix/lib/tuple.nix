# Custom tuple type for NixOS modules
# Provides type-safe fixed-length tuples with per-position type validation
#
# This type is designed to accurately represent Terraform's tuple types in NixOS modules.
# Unlike `types.listOf`, this enforces a fixed length and different types at each position.
#
# Usage:
#   types.tupleOf [ types.str types.number types.bool ]
#
# This creates a tuple that expects exactly 3 elements:
#   - Position 0: string
#   - Position 1: number
#   - Position 2: boolean
#
# Example valid value: [ "hello" 42 true ]
# Example invalid values:
#   - [ "hello" 42 ]           # Wrong length (too short)
#   - [ "hello" 42 true false ] # Wrong length (too long)
#   - [ "hello" "world" true ]  # Wrong type at position 1 (expected number)
{lib}:
with lib;
with lib.types; let
  # Main tuple type constructor
  #
  # Args:
  #   elemTypes: List of NixOS types, one for each position in the tuple
  #
  # Returns:
  #   A NixOS option type that validates tuples
  tupleOf = elemTypes: let
    tupleLength = builtins.length elemTypes;

    # Generate human-readable description like "tuple of [str, number, bool]"
    typeDesc =
      lib.concatStringsSep ", "
      (map (t: t.description or t.name) elemTypes);

    # Generate name with type info
    typeName = "tupleOf[${toString tupleLength}]";
  in
    mkOptionType {
      name = typeName;

      description = "tuple of [${typeDesc}]";
      descriptionClass = "composite";

      # Check function: validates that value is a list of the correct length
      # Note: We only check length here for performance (NixOS pattern)
      # Element type checking happens during merge
      check = value:
        isList value && (builtins.length value == tupleLength);

      # Merge function: combines multiple definitions and validates element types
      # This is where per-element type validation occurs
      merge = loc: defs: let
        # Extract values from all definitions
        values = map (def: def.value) defs;

        # Validate all values have correct length
        lengthErrors = filter (v: builtins.length v != tupleLength) values;

        # If any value has wrong length, throw error
        throwIfLengthErrors = lib.throwIf (lengthErrors != []) ''
          The option `${showOption loc}' expects a tuple of length ${toString tupleLength},
          but received value(s) with incorrect length.
          Expected: ${toString tupleLength} elements
        '';

        # Merge elements position-by-position using the appropriate type's merge
        mergeAt = i: elemType: let
          # Create definitions for this position from all provided tuples
          elementDefs =
            map (
              def: {
                inherit (def) file;
                value = builtins.elemAt def.value i;
              }
            )
            defs;

          # Location for this element (for error messages)
          elemLoc = loc ++ ["[${toString i}]"];

          # Merge the element using its type's merge function
          mergedValue = elemType.merge elemLoc elementDefs;

          # Validate the merged value against the element type
          typeCheckPassed = elemType.check mergedValue;
        in
          # Throw error if type check fails
          if !typeCheckPassed
          then
            throw ''
              The option `${showOption elemLoc}' has an invalid value.
              Expected type: ${elemType.description or elemType.name}
              Actual value: ${builtins.toString mergedValue}
            ''
          else mergedValue;
      in
        throwIfLengthErrors (
          # Build the final tuple by merging each position
          lib.genList
          (i: mergeAt i (builtins.elemAt elemTypes i))
          tupleLength
        );

      # Functor: enables type composition (wrapping with nullOr, either, etc.)
      functor = {
        # Type function: reconstructs the type from payload
        type = payload: tupleOf payload.elemTypes;

        # Payload: holds the element types
        payload = {inherit elemTypes;};

        # Binary operation: merge two tuple type payloads
        # Only compatible if element types match
        binOp = a: b:
          if a.elemTypes == b.elemTypes
          then a
          else null;
      };

      # Nested types: for documentation generation
      # Maps each position to its type
      nestedTypes = builtins.listToAttrs (
        lib.imap0 (i: t: {
          name = "[${toString i}]";
          value = t;
        })
        elemTypes
      );

      # Get sub-options: for documentation of nested structures
      # This is called when generating module documentation
      getSubOptions = prefix: let
        # For each element type that has sub-options (like submodule)
        # generate documentation with appropriate path
        genSubOpts = i: elemType:
          if elemType ? getSubOptions
          then elemType.getSubOptions (prefix ++ ["[${toString i}]"])
          else {};
      in
        # Merge all sub-options from all positions
        foldl' (acc: i: acc // genSubOpts i (builtins.elemAt elemTypes i))
        {}
        (lib.range 0 (tupleLength - 1));

      # Get submodules: returns submodules from all element types
      # Used for composed types that contain submodules
      getSubModules = lib.concatLists (filter (x: x != null) (map (t: t.getSubModules or []) elemTypes));

      # Substrate: internal type representation for advanced use cases
      # Substitutes submodules in all element types
      # Only call substSubModules if the type actually contains submodules
      # to avoid creating broken types (e.g., listOf with null elemType)
      substSubModules = m:
        tupleOf (
          map (
            t: let
              # getSubModules can return null, [], or a non-empty list
              submodules = t.getSubModules or null;
              hasSubModules = builtins.isList submodules && submodules != [];
            in
              # Only substitute if type has submodules, otherwise return unchanged
              if hasSubModules
              then t.substSubModules m
              else t
          )
          elemTypes
        );
    };
in {
  inherit tupleOf;
}

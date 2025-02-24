toml:
with builtins;
let
  content = fromTOML (readFile toml);
  setToString =
    set:
    let
      keys = attrNames set;
      keyValues = map (name: "${name} = ${setToString (getAttr name set)};") keys;
      setStr = "{ ${concatStringsSep " " keyValues} }";
    in
    if typeOf set == "set" then
      setStr
    else if typeOf set == "list" then
      "[ ${concatStringsSep " " (map setToString set)} ]"
    else
      toJSON set;

  txt = ''
    {
      inputs = ${setToString (content.inputs or { })};
      outputs = inputs: {
        lib.overlays = ${setToString content.overlays or [ ]};
        lib.nix-config = ${setToString content.nix-config or { }};
      };
    }
  '';
in
txt

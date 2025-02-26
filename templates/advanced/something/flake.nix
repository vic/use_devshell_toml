{
  outputs = _inputs: {
    overlays.foo = final: _prev: {
      foo = final.writeShellScriptBin "foo" "echo FOO";
    };

    overlays.moo = final: _prev: {
      moo = final.writeShellScriptBin "moo" "echo MOO";
    };
  };
}

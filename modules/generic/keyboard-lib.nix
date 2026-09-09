{
  /**
    Normalize a keyboard layout entry to the canonical attrset form.

    Accepts either a layout code string or an attrset that may omit optional
    fields. The returned attrset always contains `layout`, `variant`, `ime`,
    and `label`, with sensible defaults applied for anything the caller did
    not supply. Used by NixOS and Home Manager keyboard modules so downstream
    consumers can always assume the full shape.

    # Inputs

    `layout`
    : Either a layout code (e.g. `"us"`) or an attrset with at least
      `layout` set. Recognized attrset fields:

      - `layout` (string): XKB layout code.
      - `variant` (string, optional): XKB variant. Defaults to `""`.
      - `ime` (string or null, optional): fcitx5 IME engine
        (`"pinyin"`, `"mozc"`, `"hangul"`, …). Defaults to `null`.
      - `label` (string or null, optional): Human-readable label. Defaults
        to `null`.

    # Type

    ```
    normalizeLayout :: (String | AttrSet) -> AttrSet
    ```

    # Examples

    :::{.example}
    ## `normalizeLayout` usage example

    ```nix
    normalizeLayout "us"
    => {
      layout = "us";
      variant = "";
      ime = null;
      label = null;
    }

    normalizeLayout { layout = "cn"; ime = "pinyin"; }
    => {
      layout = "cn";
      variant = "";
      ime = "pinyin";
      label = null;
    }
    ```
    :::
  */
  normalizeLayout =
    layout:
    if builtins.isString layout then
      {
        inherit layout;
        variant = "";
        ime = null;
        label = null;
      }
    else
      # Fill in the optional fields rather than returning the attrset as given.
      # A bare passthrough here contradicted the documented example above and
      # the promise that the result always carries all four keys: a caller
      # passing `{ layout = "cn"; ime = "pinyin"; }` got no `variant` or
      # `label`, so every consumer had to guard with `or` anyway.
      {
        variant = "";
        ime = null;
        label = null;
      }
      // layout;
}

{
  helpers,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) testNixOS withTestUser;

  withHM =
    extra:
    withTestUser (
      {
        marchyo.desktop.enable = true;
        home-manager.users.testuser = {
          imports = [ homeManagerModules ];
        };
      }
      // extra
    );
in
{
  eval-emacs-disabled = testNixOS "emacs-disabled" (withHM { });

  eval-emacs-enabled = testNixOS "emacs-enabled" (withHM {
    marchyo.emacs.enable = true;
  });

  # Every sub-feature off — module should still evaluate.
  eval-emacs-minimal = testNixOS "emacs-minimal" (withHM {
    marchyo.emacs.enable = true;
    marchyo.emacs.windmove.enable = false;
    marchyo.emacs.eventListener.enable = false;
    marchyo.emacs.scratchpad.enable = false;
    marchyo.emacs.everywhere.enable = false;
    marchyo.emacs.orgProtocol.enable = false;
  });
}

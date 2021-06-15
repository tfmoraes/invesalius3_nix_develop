{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    pypi-deps-db = {
      url = "github:DavHau/pypi-deps-db/71447b5cea3eb5f833e70a20421be958d4c6bb3f";
      flake = false;
    };
    mach-nix = {
      url = github:DavHau/mach-nix;
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.pypi-deps-db.follows = "pypi-deps-db";
    };
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, pypi-deps-db }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        mach-nix-utils = import mach-nix {
          inherit pkgs;
        };

        my_python = mach-nix-utils.mkPython {
          requirements = ( builtins.readFile ./requirements.txt ) + ''
            ipython
          '';

          _.enum34.phases = "installPhase";
          _.enum34.installPhase = "mkdir $out";

          _.plaidml.pipInstallFlags = "--no-deps";
          _.plaidml-keras.pipInstallFlags = "--no-deps";

          overridesPost = [
            (
              self: super: {
                wxpython = super.wxpython.overridePythonAttrs (old: rec{
                  DOXYGEN = "${pkgs.doxygen}/bin/doxygen";

                  localPython = self.python.withPackages (ps: with ps; [
                    setuptools
                    numpy
                    six
                  ]);

                  nativeBuildInputs = with pkgs; [
                    which
                    doxygen
                    gtk3
                    pkg-config
                    autoPatchelfHook
                  ] ++ old.nativeBuildInputs;

                  buildInputs = with pkgs; [
                    gtk3
                    webkitgtk
                    ncurses
                    SDL2
                    xorg.libXinerama
                    xorg.libSM
                    xorg.libXxf86vm
                    xorg.libXtst
                    xorg.xorgproto
                    gst_all_1.gstreamer
                    gst_all_1.gst-plugins-base
                    libGLU
                    libGL
                    libglvnd
                    mesa
                  ] ++ old.buildInputs;

                  buildPhase = ''
                    ${localPython.interpreter} build.py -v build_wx
                    ${localPython.interpreter} build.py -v dox etg --nodoc sip
                    ${localPython.interpreter} build.py -v build_py
                  '';

                  installPhase = ''
                    ${localPython.interpreter} setup.py install --skip-build --prefix=$out
                  '';
                });
              }
            )
          ];
        };
      in
      {
        devShell = pkgs.mkShell {
          name = "InVesalius";
          buildInputs = with pkgs; [
            my_python
            gtk3
            glib
            gsettings-desktop-schemas
          ];

          nativeBuildInputs = with pkgs; [
            gobject-introspection
            wrapGAppsHook
          ];
        };
      });
}

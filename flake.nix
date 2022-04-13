{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    pypi-deps-db = {
      url = "github:DavHau/pypi-deps-db";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.mach-nix.follows = "mach-nix";
    };
    mach-nix = {
      url = "github:DavHau/mach-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.pypi-deps-db.follows = "pypi-deps-db";
    };
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, pypi-deps-db }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        # mach-nix-utils = import mach-nix {
        #   inherit pkgs;
        #   python = "python38";
        #   pypiDataRev = pypi-deps-db.rev;
        #   pypiDataSha256 = pypi-deps-db.narHash;
        # };
        mach-nix-utils = mach-nix.lib.${system};

        my_python = mach-nix-utils.mkPython {
          python = "python38";
          requirements = (builtins.readFile ./requirements.txt) + ''
            ipython
            setuptools_rust
            pyacvd
            dipy
            scikit-learn
            onnxruntime-gpu
            itk-elastix
          '';

          providers.wxpython = "nixpkgs";

          _.enum34.phases = "installPhase";
          _.enum34.installPhase = "mkdir $out";

          _.plaidml.pipInstallFlags = "--no-deps";
          _.plaidml-keras.pipInstallFlags = "--no-deps";

          _.numpy.propagatedBuildInputs.add = [pkgs.zlib];

          # overridesPost = [(
          #   self: super: {
          #     jax = super.jax.overridePythonAttrs (old: rec{
          #       propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [
          #         self.jaxlib
          #       ];
          #     });
          #   })
          # ];
          #       wxpython = super.wxpython.overridePythonAttrs (old: rec{
          #         DOXYGEN = "${pkgs.doxygen}/bin/doxygen";

          #         localPython = self.python.withPackages (ps: with ps; [
          #           setuptools
          #           numpy
          #           six
          #         ]);

          #         nativeBuildInputs = with pkgs; [
          #           which
          #           doxygen
          #           gtk3
          #           pkg-config
          #           autoPatchelfHook
          #         ] ++ old.nativeBuildInputs;

          #         buildInputs = with pkgs; [
          #           gtk3
          #           webkitgtk
          #           ncurses
          #           SDL2
          #           xorg.libXinerama
          #           xorg.libSM
          #           xorg.libXxf86vm
          #           xorg.libXtst
          #           xorg.xorgproto
          #           gst_all_1.gstreamer
          #           gst_all_1.gst-plugins-base
          #           libGLU
          #           libGL
          #           libglvnd
          #           mesa
          #         ] ++ old.buildInputs;

          #         buildPhase = ''
          #           ${localPython.interpreter} build.py -v --jobs=8 build_wx
          #           ${localPython.interpreter} build.py -v dox etg --nodoc sip
          #           ${localPython.interpreter} build.py -v --jobs=8 build_py
          #         '';

          #         installPhase = ''
          #           ${localPython.interpreter} setup.py install --skip-build --prefix=$out
          #         '';
          #       });
          #     }
          #   )
          # ];
        };
        gpu_libs = with pkgs; [
          cudaPackages_11.cudatoolkit
          cudaPackages_11.cudatoolkit.lib
          cudaPackages_11.cudnn
          ocl-icd
        ];
      in
      {
        devShell = pkgs.mkShell {
          name = "InVesalius";
          buildInputs = with pkgs; [
            my_python
            gtk3
            glib
            gsettings-desktop-schemas
            clinfo
            zlib
          ] ++ gpu_libs;

          nativeBuildInputs = with pkgs; [
            gobject-introspection
            wrapGAppsHook
          ];

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (gpu_libs ++ [ "/run/opengl-driver" ]);
        };

        defaultPackage = my_python;
      });
}

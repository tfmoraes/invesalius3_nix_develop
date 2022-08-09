{
  description = "Application packaged using poetry2nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.poetry2nix_pkgs.url = "github:nix-community/poetry2nix";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix_pkgs,
  }: (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    poetry2nix = import poetry2nix_pkgs {
      inherit pkgs;
      poetry = pkgs.poetry;
    };

    customOverrides = self: super: {
      scikit-build = super.scikit-build.overridePythonAttrs (
        old: {
          buildInputs = [self.wheel] ++ (old.buildInputs or []);
        }
      );
      plaidml = super.plaidml.overridePythonAttrs (old: {
        pipInstallFlags = "--no-deps";
      });

      plaidml-keras = super.plaidml-keras.overridePythonAttrs (old: {
        pipInstallFlags = "--no-deps";
      });

      wxpython = super.wxpython.overridePythonAttrs (old: {
        buildInputs = [self.attrdict] ++ (old.buildInputs or []);
        nativeBuildInputs = [self.sip] ++ (old.nativeBuildInputs or []);
      });
    };

    gpu_libs = with pkgs; [
      cudaPackages_11.cudatoolkit
      cudaPackages_11.cudatoolkit.lib
      cudaPackages_11.cudnn
      cudaPackages_11.libcufft
      cudaPackages_11.libcublas
      cudaPackages_11.libcurand
      ocl-icd
    ];

    my_env =
      poetry2nix.mkPoetryEnv
      {
        projectDir = ./.;
        preferWheels = true;
        overrides = [poetry2nix.defaultPoetryOverrides customOverrides];
        python = pkgs.python38;
      };
  in {
    devShell = pkgs.mkShell {
      buildInputs = with pkgs;
        [
          poetry
          my_env
          gtk3
          glib
          gsettings-desktop-schemas
          clinfo
          zlib
          cmake
        ]
        ++ gpu_libs;
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath ["/run/opengl-driver"];
    };
    defaultPackage = my_env;
  }));
}

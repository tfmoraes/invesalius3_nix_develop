{
  description = "Application packaged using poetry2nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.poetry2nix = {
    url = "github:nix-community/poetry2nix";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , poetry2nix
    ,
    }: (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ poetry2nix.overlay ];
      };

      customOverrides = self: super: {
        scikit-build = super.scikit-build.overridePythonAttrs (
          old: {
            buildInputs = [ self.wheel ] ++ (old.buildInputs or [ ]);
          }
        );
        plaidml = super.plaidml.overridePythonAttrs (old: {
          pipInstallFlags = "--no-deps";
        });

        plaidml-keras = super.plaidml-keras.overridePythonAttrs (old: {
          pipInstallFlags = "--no-deps";
        });

        pyacvd = super.pyacvd.overridePythonAttrs (old: {
          buildInputs = [ self.cython ] ++ (old.buildInputs or [ ]);
        });

        # wxpython = pkgs.python311Packages.wxPython_4_2;
        wxpython = super.wxpython.overridePythonAttrs (old: {
          buildInputs =
            [
              self.attrdict
              self.setuptools
            ]
            ++ (old.buildInputs or [ ]);
          nativeBuildInputs = [ self.sip ] ++ (old.nativeBuildInputs or [ ]);
        });

        pybind11 = pkgs.python311Packages.pybind11;

        torch = super.torch.overridePythonAttrs
          (old: {
            buildInputs = [
              self.nvidia-cublas-cu11
              self.nvidia-cuda-cupti-cu11
              self.nvidia-cuda-nvrtc-cu11
              self.nvidia-cuda-runtime-cu11
              self.nvidia-cudnn-cu11
              self.nvidia-cufft-cu11
              self.nvidia-curand-cu11
              self.nvidia-cusolver-cu11
              self.nvidia-cusparse-cu11
              self.nvidia-nccl-cu11
              self.nvidia-nvtx-cu11
              self.triton
            ] ++ (old.buildInputs or [ ]);
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

        my_env = (pkgs.poetry2nix.mkPoetryEnv
          {
            projectDir = ./.;
            preferWheels = true;
            overrides = [ customOverrides pkgs.poetry2nix.defaultPoetryOverrides ];
            python = pkgs.python311;
          }).override { ignoreCollisions = true; };
        in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            poetry
            my_env
            gtk3
            glib
            gsettings-desktop-schemas
            clinfo
            zlib
            cmake
          ];
          # ++ gpu_libs;
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            "/run/opengl-driver"
            "${my_env}/${my_env.python.sitePackages}/nvidia/cudnn"
            "${my_env}/${my_env.python.sitePackages}/nvidia/cublas"
          ];
        };
        defaultPackage = my_env;
      }));
      }

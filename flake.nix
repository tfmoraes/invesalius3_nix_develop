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

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
  }: (flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [poetry2nix.overlay];
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

      pyacvd = super.pyacvd.overridePythonAttrs (old: {
        buildInputs = [self.cython] ++ (old.buildInputs or []);
      });

      wxpython = pkgs.python311Packages.wxPython_4_2;

      lit = super.lit.overridePythonAttrs (old: {
        buildInputs = [self.setuptools];
      });

      pybind11 = pkgs.python311Packages.pybind11;

      # The following are dependencies of torch >= 2.0.0.
      # torch doesn't officially support system CUDA, unless you build it yourself.
      nvidia-cudnn-cu11 = super.nvidia-cudnn-cu11.overridePythonAttrs (attrs: {
        autoPatchelfIgnoreMissingDeps = true;
        # (Bytecode collision happens with nvidia-cuda-nvrtc-cu11.)
        postFixup = ''
          rm -r $out/${self.python.sitePackages}/nvidia/{__pycache__,__init__.py}
        '';
        propagatedBuildInputs =
          attrs.propagatedBuildInputs
          or []
          ++ [
            self.nvidia-cublas-cu11
          ];
      });

      nvidia-cuda-nvrtc-cu11 = super.nvidia-cuda-nvrtc-cu11.overridePythonAttrs (_: {
        # (Bytecode collision happens with nvidia-cudnn-cu11.)
        postFixup = ''
          rm -r $out/${self.python.sitePackages}/nvidia/{__pycache__,__init__.py}
        '';
      });

      nvidia-cusolver-cu11 = super.nvidia-cusolver-cu11.overridePythonAttrs (attrs: {
        autoPatchelfIgnoreMissingDeps = true;
        # (Bytecode collision happens with nvidia-cusolver-cu11.)
        postFixup = ''
          rm -r $out/${self.python.sitePackages}/nvidia/{__pycache__,__init__.py}
        '';
        propagatedBuildInputs =
          attrs.propagatedBuildInputs
          or []
          ++ [
            self.nvidia-cublas-cu11
          ];
      });

      torch = super.torch.overridePythonAttrs (old: {
        nativeBuildInputs =
          old.nativeBuildInputs
          or []
          ++ [
            pkgs.autoPatchelfHook
            pkgs.cudaPackages.autoAddOpenGLRunpathHook
          ];
        buildInputs =
          old.buildInputs
          or []
          ++ [
            self.nvidia-cudnn-cu11
            self.nvidia-cuda-nvrtc-cu11
            self.nvidia-cuda-runtime-cu11
            self.nvidia-cublas-cu11
          ];
        postInstall = ''
          addAutoPatchelfSearchPath "${self.nvidia-cublas-cu11}/${self.python.sitePackages}/nvidia/cublas/lib"
          addAutoPatchelfSearchPath "${self.nvidia-cudnn-cu11}/${self.python.sitePackages}/nvidia/cudnn/lib"
          addAutoPatchelfSearchPath "${self.nvidia-cuda-nvrtc-cu11}/${self.python.sitePackages}/nvidia/cuda_nvrtc/lib"
        '';
      });
      triton = super.triton.overridePythonAttrs (old: {
        propagatedBuildInputs = builtins.filter (e: e.pname != "torch") old.propagatedBuildInputs;
        pipInstallFlags = ["--no-deps"];
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
      (pkgs.poetry2nix.mkPoetryEnv
      {
        projectDir = ./.;
        preferWheels = true;
        overrides = [customOverrides pkgs.poetry2nix.defaultPoetryOverrides];
        python = pkgs.python311;
      }).override {ignoreCollisions = true;};
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

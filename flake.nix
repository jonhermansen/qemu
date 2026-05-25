{
  description = "QEMU — built from source with HVF and vmapple support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    keycodemapdb = {
      url = "gitlab:qemu-project/keycodemapdb/f5772a62ec52591ff6870b7e8ef32482371f22c6";
      flake = false;
    };
    berkeley-softfloat-3 = {
      url = "gitlab:qemu-project/berkeley-softfloat-3/b64af41c3276f97f0e181920400ee056b9c88037";
      flake = false;
    };
    berkeley-testfloat-3 = {
      url = "gitlab:qemu-project/berkeley-testfloat-3/e7af9751d9f9fd3b47911f51a5cfd08af256a9ab";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, keycodemapdb, berkeley-softfloat-3, berkeley-testfloat-3 }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system} = {
        qemu = pkgs.qemu.overrideAttrs (old: {
          pname = "qemu-vmapple";
          version = "unstable-2026-05-25";
          src = self;
          patches = [];
          outputs = [ "out" ];

          buildInputs = (old.buildInputs or []) ++ [
            pkgs.apple-sdk_15
            (pkgs.darwinMinVersionHook "15.0")
          ];

          postUnpack = ''
            rm -rf $sourceRoot/subprojects/keycodemapdb
            cp -r ${keycodemapdb} $sourceRoot/subprojects/keycodemapdb
            rm -rf $sourceRoot/subprojects/berkeley-softfloat-3
            cp -r ${berkeley-softfloat-3} $sourceRoot/subprojects/berkeley-softfloat-3
            chmod -R u+w $sourceRoot/subprojects/berkeley-softfloat-3
            cp -r $sourceRoot/subprojects/packagefiles/berkeley-softfloat-3/* $sourceRoot/subprojects/berkeley-softfloat-3/
            rm -rf $sourceRoot/subprojects/berkeley-testfloat-3
            cp -r ${berkeley-testfloat-3} $sourceRoot/subprojects/berkeley-testfloat-3
            chmod -R u+w $sourceRoot/subprojects/berkeley-testfloat-3
            cp -r $sourceRoot/subprojects/packagefiles/berkeley-testfloat-3/* $sourceRoot/subprojects/berkeley-testfloat-3/
          '';

          postPatch = ''
            sed -i '/^Rez /d; /^SetFile /d' scripts/entitlement.sh
          '';

          preConfigure = ''
            unset CPP
            chmod +x ./scripts/shaderinclude.py
            patchShebangs .
            mv VERSION QEMU_VERSION
            substituteInPlace configure \
              --replace-fail '$source_path/VERSION' '$source_path/QEMU_VERSION'
            substituteInPlace meson.build \
              --replace-fail "'VERSION'" "'QEMU_VERSION'"
            substituteInPlace docs/conf.py \
              --replace-fail "'../VERSION'" "'../QEMU_VERSION'"
            substituteInPlace python/qemu/machine/machine.py \
              --replace-fail /var/tmp "$TMPDIR"
          '';

          configureFlags = [
            "--disable-strip"
            "--target-list=aarch64-softmmu,x86_64-softmmu"
            "--enable-cocoa"
            "--enable-hvf"
            "--enable-slirp"
            "--enable-gnutls"
            "--disable-sdl"
            "--disable-gtk"
            "--disable-werror"
            "--disable-docs"
            "--disable-guest-agent"
          ];
        });
        default = self.packages.${system}.qemu;
      };
    };
}

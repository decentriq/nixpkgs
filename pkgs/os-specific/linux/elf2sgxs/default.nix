{ stdenv, pkgs, fetchFromGitHub, rustPlatform, ... }:
let
  rustOverlay = import ./mozilla-rust-overlay.nix pkgs pkgs;
  rustNightly = rustOverlay.rustNightly2019_09_27;
in
rustPlatform.buildRustPackage rec {
  name = "elf2sgxs";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "fortanix";
    repo = "rust-sgx";
    rev = "83ca347bd3d2f91ed09c4868b5a7cee225507fe8";
    sha256 = "0m5m75wq8hs388ljlssr46vwibnybd61mlz23rka46sk5n8s72pf";
  };
  cargoSha256 = "0bbasg4b6gp3bsj0dyg2b4y84d2j2w19hs7xn3zg2mk21svvg6z4";

  nativeBuildInputs = [ rustNightly.rust rustNightly.cargo ];
  buildInputs = [ pkgs.cacert pkgs.git pkgs.pkgconfig pkgs.openssl pkgs.protobuf ];

  buildPhase = "cargo build --package fortanix-sgx-tools --bin ftxsgx-elf2sgxs --release";
  checkPhase = "cargo test --package fortanix-sgx-tools --release";
  installPhase = "install -vD target/release/ftxsgx-elf2sgxs $out/bin/ftxsgx-elf2sgxs";

  meta = with stdenv.lib; {
    description = "Installs ftxsgx-elf2sgxs, which converts a 64bit ELF SGX enclave into an SGXS enclave";
    homepage = https://github.com/fortanix/rust-sgx;
    license = licenses.mpl20;
    maintainers = [ maintainers.exfalso ];
    platforms = platforms.linux;
  };
}

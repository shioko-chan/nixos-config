{ p2pool, fetchFromGitHub }:
p2pool.overrideAttrs (_: rec {
  version = "4.18";
  src = fetchFromGitHub {
    owner = "SChernykh";
    repo = "p2pool";
    rev = "v${version}";
    hash = "sha256-nmh6XY7fP/qddzVyb1yiJ5dcOxZctCjodi5uf3M3NfM=";
    fetchSubmodules = true;
  };
})

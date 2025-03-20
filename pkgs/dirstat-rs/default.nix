{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "dirstat-rs";
  version = "0.3.7";

  src = fetchFromGitHub {
    owner = "scullionw";
    repo = "dirstat-rs";
    rev = "v${version}";
    hash = "sha256-gDIUYhc+GWbQsn5DihnBJdOJ45zdwm24J2ZD2jEwGyE=";
  };

  cargoHash = "sha256-lgvuiVCcFrnawmj/dNn/SzUj5k8LVNQ649eqOSDbJbQ=";

  meta = {
    description = "Fastest(?) disk usage cli, similar to windirstat";
    homepage = "https://github.com/scullionw/dirstat-rs";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ alanpearce ];
    mainProgram = "dirstat-rs";
  };
}

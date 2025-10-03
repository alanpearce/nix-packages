{
  lib,
  stdenv,
  fetchFromGitHub,
  ncurses,
  nodejs,
  bun,
  pnpm,
  yarn,
  just,
  nix,
}:
stdenv.mkDerivation rec {
  pname = "projectdo";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "paldepind";
    repo = "projectdo";
    rev = "v${version}";
    hash = "sha256-bdSwpfHipL1fuXjvVifaKNV477JENYu7SxKMpk3ZP6o=";
  };

  dontConfigure = true;
  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    make test
  '';

  nativeBuildInputs = [
    ncurses
  ];

  nativeCheckInputs = [
    bun
    nodejs
    pnpm
    yarn
    just
    nix
  ];

  installPhase = ''
    make PREFIX=$out install
    install -D functions/* -t $out/share/fish/vendor_functions.d
    install -D completions/* -t $out/share/fish/vendor_completions.d
  '';

  meta = {
    description = "Context-aware single-letter project commands to speed up your terminal workflow";
    homepage = "https://github.com/paldepind/projectdo";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ alanpearce ];
    mainProgram = "projectdo";
    platforms = lib.platforms.all;
  };
}

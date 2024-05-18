{ stdenv
, emacs
}:

assert stdenv.isDarwin;

emacs.overrideAttrs (old: {
  NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") +
    " -DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT";
})

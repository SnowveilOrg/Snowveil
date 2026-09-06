{
  system = "x86_64-linux";
  roles = [
    "desktop"
    "development"
  ];
  profiles = [
    "workstation"
    "personal"
  ];

  home.useGlobalPkgs = false;

  snowveil = {
    overlays.example.enable = true;
    packages = {
      hello = {
        enable = true;
        scope = "system";
      };
      overlay-consumer = {
        enable = true;
        scope = "home";
      };
    };
  };
}

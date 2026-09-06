{
  system = "x86_64-linux";
  roles = [ "server" ];
  profiles = [ "workstation" ];

  snowveil.modules.workstation.podman.enable = false;
  snowveil.overlays.example.enable = false;

  home.embed = false;
}

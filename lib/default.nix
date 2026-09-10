{ lib }:

# Snowveil - 库入口
# 结构：
#   ./discover.nix  - 目录自动发现
#   ./host.nix      - 主机元数据
#   ./sops.nix      - SOPS 密钥管理
#   ./patches.nix   - Patch 帮助函数
#   ./fs.nix        - 文件系统遍历
#   ./internal/     - 框架内部模块

let
  fs = import ./fs.nix { inherit lib; };
  patches = import ./patches.nix;
  sourceTools = import ./source.nix { inherit lib; };
  moduleTools = import ./internal/modules.nix { inherit lib; };
  depGraph = import ./internal/depgraph.nix { inherit lib; };
  profileTools = import ./internal/profiles.nix { inherit lib; };
  userTools = import ./user.nix { inherit lib; };
  utils = import ./internal/utils.nix { inherit lib; };
  builtinOptions = import ./internal/options.nix { };
  validationTools = import ./internal/validation.nix { inherit lib; };
  outputTools = import ./internal/outputs.nix { inherit lib; };

  inherit (utils) renderOptions;
  inherit (builtinOptions) optionsSnowveil optionsSnowveilHome;

  defaultSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  forAllSystems = systems: f: lib.genAttrs systems f;
  sortNames = lib.sort (a: b: a < b);

  version = {
    major = 0;
    minor = 5;
    patch = 0;
    pre = "dev";
    string = "0.5.0-dev";
  };

  bind =
    {
      inputs,
      moduleRegistries ? [ ],
      moduleGroups ? { },
      profiles ? { },
      root ? null,
      sops ? { },
    }:
    let
      self =
        inputs.self
          or (throw "error: missing required flake input

  Snowveil requires inputs.self
  make sure 'self' is included in your flake inputs");
      nixpkgs =
        inputs.nixpkgs
          or (throw "error: missing required flake input

  Snowveil requires inputs.nixpkgs
  make sure 'nixpkgs' is included in your flake inputs");
      nixosSystem = nixpkgs.lib.nixosSystem;
      hm = inputs.home-manager or null;
      projectRoot = if root == null then toString self.outPath else toString root;
      channels = { inherit nixpkgs; };

      discovered = import ./discover.nix {
        inherit
          lib
          fs
          projectRoot
          moduleRegistries
          moduleGroups
          profiles
          ;
      };

      hostMeta = import ./host.nix {
        inherit lib discovered;
      };

      schema = import ./schema.nix;

      sopsLayout = sops.layout or null;
      sops' = import ./sops.nix { inherit projectRoot sopsLayout; };
      source = sourceTools // {
        clean = args: sourceTools.clean ({ root = projectRoot; } // args);
      };
      projectSource = source.clean { };
      snowveilInject = {
        inherit
          patches
          version
          source
          projectSource
          ;
        sops = sops';
        inherit tests;
        lint =
          {
            root ? projectRoot,
          }:
          let
            pkgs = nixpkgs.legacyPackages.${builtins.currentSystem} or nixpkgs.legacyPackages.x86_64-linux;
            tools = [
              pkgs.treefmt
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
            ];
            configFile = pkgs.writeText "treefmt.toml" (builtins.readFile (root + "/treefmt.toml"));
          in
          pkgs.writeShellScriptBin "snowveil-lint" ''
            export PATH=${pkgs.lib.makeBinPath tools}:$PATH
            exec ${pkgs.treefmt}/bin/treefmt --config-file ${configFile} --tree-root ${root} "$@"
          '';
      };
      snowveil = snowveilInject;

      # overlays: 支持两种签名
      #   final: prev: { ... }                      标准 nixpkgs overlay
      #   { inputs, self, snowveil }: final: prev: ... 带框架参数的解构签名
      loadOverlay =
        path:
        let
          imported = import path;
          argNames = builtins.functionArgs imported;
          isStructured = argNames ? inputs || argNames ? self || argNames ? snowveil;
        in
        if isStructured then imported { inherit inputs self snowveil; } else imported;

      overlays = lib.listToAttrs (
        map (o: lib.nameValuePair o.name (loadOverlay o.path)) discovered.overlays
      );
      overlayList = lib.attrValues overlays;

      overlayListForHost =
        host:
        map (overlay: overlays.${overlay.name}) (
          lib.filter (
            overlay: (hostPlans.${host}.metadata.overlays.${overlay.name} or true)
          ) discovered.overlays
        );

      pkgsFor =
        {
          system,
          nixpkgsConfig ? { },
          extraOverlays ? [ ],
          overlays ? overlayList,
        }:
        # Check simple conditions first: list comparisons are cheaper than attrset equality
        if
          extraOverlays == [ ]
          && overlays == [ ]
          && nixpkgsConfig == { }
          && builtins.hasAttr system (nixpkgs.legacyPackages or { })
        then
          nixpkgs.legacyPackages.${system}
        else
          import nixpkgs {
            inherit system;
            config = nixpkgsConfig;
            overlays = overlays ++ extraOverlays;
          };

      importFile =
        path:
        let
          imported = import path;
          declared = if builtins.isFunction imported then builtins.functionArgs imported else { };
          args = builtins.intersectAttrs declared {
            inherit
              lib
              inputs
              self
              snowveil
              ;
          };
        in
        if builtins.isFunction imported then imported args else imported;

      callPackage =
        pkgs: path:
        let
          fn = import path;
          declared = builtins.functionArgs fn;
          extras = lib.intersectAttrs declared { inherit inputs self snowveil; };
        in
        pkgs.callPackage fn extras;

      specialArgsFor =
        extraSpecialArgs:
        {
          inherit
            inputs
            self
            channels
            snowveil
            ;
        }
        // extraSpecialArgs;

      usersForHost = host: discovered.usersByHost.${host} or [ ];

      selectLocalModules =
        {
          side,
          roles,
          overrideMap,
          profileEnabled ? [ ],
          target,
        }:
        let
          graph = discovered.moduleGraph.${side};
          moduleIndex = discovered.localGroupedModules.index;
          sideOnly = if side == "nixos" then "nixosOnly" else "homeOnly";
          rolesSet = if roles == null then null else lib.genAttrs roles (_: true);
          profileSet = lib.genAttrs profileEnabled (_: true);
          # Filter out explicitly disabled modules first to avoid unnecessary path computations
          candidateNames = lib.filter (name: (overrideMap.${name} or null) != false) (builtins.attrNames graph.nodes);
          selectedByName = builtins.listToAttrs (
            map (
              name:
              let
                node = graph.nodes.${name};
                record = moduleIndex.${name};
                roleMatches = record.common || rolesSet == null || builtins.hasAttr record.role rolesSet;
                defaultPaths = record.shared ++ lib.optionals roleMatches record.${sideOnly};
                override = overrideMap.${name} or null;
                paths =
                  if override == true || builtins.hasAttr name profileSet then
                    node.paths
                  else
                    defaultPaths;
              in
              lib.nameValuePair name paths
            ) candidateNames
          );
          allNames = builtins.attrNames graph.nodes;
          enabled = lib.filter (name: builtins.hasAttr name selectedByName && selectedByName.${name} != [ ]) candidateNames;
          enabledSet = lib.genAttrs enabled (_: true);
          disabled = lib.filter (name: !builtins.hasAttr name enabledSet) allNames;
          disabledReasons = builtins.listToAttrs (
            map (
              name:
              lib.nameValuePair name (
                if (overrideMap.${name} or null) == false then
                  "explicitly disabled by host module override"
                else
                  "not selected by role filter"
              )
            ) disabled
          );
          resolved = depGraph.resolve {
            inherit
              graph
              enabled
              target
              disabledReasons
              ;
          };
          paths = lib.concatMap (name: selectedByName.${name}) resolved.order;
        in
        {
          inherit (resolved)
            order
            capabilityEdges
            capabilityRequirements
            ;
          inherit paths disabled disabledReasons;
        };

      globalHomeSelection = selectLocalModules {
        side = "home";
        roles = null;
        overrideMap = { };
        target = "global home";
      };

      emptyHomeRecord = {
        defaultPath = null;
        hostModules = { };
      };

      hostPlans = lib.mapAttrs (
        host: record:
        let
          metadata = hostMeta.normalizeHostMetadata record.meta;
          declaredProfiles = profileTools.checkHostProfiles {
            inherit host;
            declared = metadata.profiles;
            knownProfiles = discovered.profiles;
          };
          profileMembers =
            side: lib.unique (lib.concatMap (profile: discovered.profiles.${profile}.${side}) declaredProfiles);
          overrideMap = moduleTools.validateModuleOverrides metadata.modules;
          select =
            side:
            selectLocalModules {
              inherit side overrideMap;
              inherit (metadata) roles;
              profileEnabled = profileMembers side;
              target = "host '${host}'";
            };
        in
        {
          inherit record metadata overrideMap;
          profiles = declaredProfiles;
          nixos = select "nixos";
          home = select "home";
        }
      ) discovered.hostsByName;

      homeModulesFor =
        {
          user,
          host ? null,
          selection ? if host == null then globalHomeSelection else hostPlans.${host}.home,
        }:
        let
          homeRecord = discovered.homesByUser.${user} or emptyHomeRecord;
          ownDefault = lib.optional (homeRecord.defaultPath != null) homeRecord.defaultPath;
          ownHost = lib.optional (
            host != null && builtins.hasAttr host homeRecord.hostModules
          ) homeRecord.hostModules.${host};
        in
        selection.paths ++ discovered.registryModules.home ++ ownDefault ++ ownHost;

      moduleReportForHost =
        hostRecord:
        let
          plan = builtins.getAttr hostRecord.name hostPlans;
          reportSide =
            side:
            let
              selected = plan.${side};
            in
            {
              enabled = selected.order;
              inherit (selected)
                disabled
                disabledReasons
                capabilityEdges
                capabilityRequirements
                ;
            };
        in
        lib.genAttrs [ "nixos" "home" ] reportSide;

      systemPlanFor =
        {
          host,
          system ? null,
          modules ? [ ],
          extraModules ? [ ],
          extraNixosModules ? [ ],
          extraHomeModules ? [ ],
          extraSpecialArgs ? { },
          extraHomeSpecialArgs ? extraSpecialArgs,
          nixpkgsConfig ? { },
          extraOverlays ? [ ],
          embedHomeManager ? true,
          homeManagerUseGlobalPkgs ? true,
          hostPackages ? [ ],
          _pkgs ? null,
          _forTest ? false,
        }:
        let
          plan = hostPlans.${host};
          hostRecord = plan.record;
          sys = if system == null then hostRecord.system else system;
          hostOverlays = overlayListForHost host;
          pkgs =
            if _pkgs == null then
              pkgsFor {
                system = sys;
                inherit nixpkgsConfig;
                inherit extraOverlays;
                overlays = hostOverlays;
              }
            else
              _pkgs;
          specialArgs = specialArgsFor extraSpecialArgs;
          homeSpecialArgs = specialArgsFor extraHomeSpecialArgs;
          hostUsers = usersForHost host;
          hostUserRecords = map (name: discovered.usersByName.${name}) hostUsers;
          hostHomeUsers = lib.filter (name: builtins.hasAttr name discovered.homesByUser) hostUsers;

          inherit (plan) metadata;
          embedForHost = hostMeta.hostPolicyFromMetadata {
            inherit metadata host;
            key = "embedHomeManager";
            fallback = hostMeta.resolveHostPolicy {
              name = "embedHomeManager";
              value = embedHomeManager;
              inherit host;
              default = true;
            };
          };
          useGlobalPkgs = hostMeta.hostPolicyFromMetadata {
            inherit metadata host;
            key = "homeManagerUseGlobalPkgs";
            fallback = hostMeta.resolveHostPolicy {
              name = "homeManagerUseGlobalPkgs";
              inherit host;
              value = homeManagerUseGlobalPkgs;
              default = true;
            };
          };

          hostModules = plan.nixos.paths ++ discovered.registryModules.nixos ++ hostRecord.modulePaths;

          userDefaultsModule = userTools.mkUsersModule {
            users = map (u: {
              inherit (u) name;
              inherit (u) meta;
            }) hostUserRecords;
            sopsFile = sops'.hostFile host;
          };
          userDefaultModules = lib.filter (p: p != null) (map (u: u.defaultPath) hostUserRecords);

          embedModule =
            { config, lib, ... }:
            let
              backupFileExtension = config.snowveil.homeManager.backupFileExtension;
            in
            {
              imports = [
                (
                  if hm == null then
                    throw "host '${host}' has associated homes (${lib.concatStringsSep ", " hostHomeUsers}) but no home-manager input is available"
                  else
                    hm.nixosModules.home-manager
                )
              ];
              home-manager = {
                inherit useGlobalPkgs;
                useUserPackages = true;
                extraSpecialArgs = homeSpecialArgs;
                users = lib.genAttrs hostHomeUsers (
                  u:
                  {
                    imports =
                      homeModulesFor {
                        user = u;
                        inherit host;
                        selection = plan.home;
                      }
                      ++ extraModules
                      ++ extraHomeModules
                      ++ lib.optional (homePackages != [ ]) homePackagesModule;
                  }
                  // lib.optionalAttrs (!useGlobalPkgs) {
                    nixpkgs = {
                      config = nixpkgsConfig;
                      overlays = hostOverlays ++ extraOverlays;
                    };
                  }
                );
              }
              // lib.optionalAttrs (backupFileExtension != null) { inherit backupFileExtension; };
            };

          setSnowveilModule = _: { config.snowveil.users = hostUsers; };

          systemPackages = map (package: callPackage pkgs package.path) (
            lib.filter (package: package.scope == "system") hostPackages
          );
          homePackages = map (package: callPackage pkgs package.path) (
            lib.filter (package: package.scope == "home") hostPackages
          );
          packagesModule = lib.optionalAttrs (systemPackages != [ ]) {
            environment.systemPackages = systemPackages;
          };
          homePackagesModule = lib.optionalAttrs (homePackages != [ ]) {
            home.packages = homePackages;
          };

          finalModules = [
            optionsSnowveil
            setSnowveilModule
          ]
          ++ lib.optional (!_forTest) (_: {
            nixpkgs = { inherit pkgs; };
          })
          ++ lib.optionals (hostUserRecords != [ ]) [ userDefaultsModule ]
          ++ userDefaultModules
          ++ lib.optionals (embedForHost && hostHomeUsers != [ ]) [ embedModule ]
          ++ lib.optional (systemPackages != [ ]) packagesModule
          ++ hostModules
          ++ modules
          ++ extraModules
          ++ extraNixosModules;
        in
        {
          inherit
            sys
            pkgs
            specialArgs
            finalModules
            ;
        };

      mkSystem =
        args:
        let
          plan = systemPlanFor args;
        in
        nixosSystem {
          system = plan.sys;
          inherit (plan) specialArgs;
          modules = plan.finalModules;
        };

      tests = {
        forHost =
          {
            host,
            testScript,
            name ? "snowveil-${host}",
            nodeName ? "machine",
            modules ? [ ],
            extraSpecialArgs ? { },
            testOptions ? { },
          }:
          let
            plan = systemPlanFor {
              inherit host extraSpecialArgs;
              extraNixosModules = modules;
              _forTest = true;
            };
          in
          plan.pkgs.testers.runNixOSTest (
            testOptions
            // {
              inherit name testScript;
              node.specialArgs = plan.specialArgs;
              nodes.${nodeName}.imports = plan.finalModules;
            }
          );
      };

      mkHome =
        {
          user,
          host ? null,
          system ? null,
          modules ? [ ],
          extraModules ? [ ],
          extraHomeModules ? [ ],
          extraSpecialArgs ? { },
          nixpkgsConfig ? { },
          extraOverlays ? [ ],
          hostPackages ? [ ],
          _pkgs ? null,
        }:
        let
          hmLib =
            if hm == null then
              throw "mkHome requires a home-manager input; add one to flake inputs"
            else
              hm.lib;
          sys =
            if host != null then
              (hostMeta.resolveHost host).system
            else if system != null then
              system
            else
              lib.head defaultSystems;
          pkgs =
            if _pkgs == null then
              if host == null then
                pkgsFor {
                  system = sys;
                  inherit nixpkgsConfig extraOverlays;
                }
              else
                pkgsFor {
                  system = sys;
                  inherit nixpkgsConfig;
                  inherit extraOverlays;
                  overlays = overlayListForHost host;
                }
            else
              _pkgs;
          selection = if host == null then globalHomeSelection else hostPlans.${host}.home;
        in
        hmLib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = specialArgsFor extraSpecialArgs;
          modules = [
            optionsSnowveilHome
          ]
          ++ homeModulesFor {
            inherit user host selection;
          }
          ++ lib.optional (host != null && hostPackages != [ ]) {
            home.packages = map (package: callPackage pkgs package.path) (
              lib.filter (package: package.scope == "home") hostPackages
            );
          }
          ++ modules
          ++ extraModules
          ++ extraHomeModules;
        };

      mkFlake =
        # 扁平参数（extraOutputs / extraSpecialArgs / extraModules /
        # extraNixosModules / extraHomeModules / nixpkgsConfig / extraOverlays /
        # embedHomeManager / homeManagerUseGlobalPkgs / disabledOutputs /
        # expectedOutputs）仍受支持以保证向后兼容，通过 args_raw 读取。
        # 嵌套命名空间（nixpkgs / nixos / home / outputs）优先。
        args_raw@{
          systems ? defaultSystems,
          # nixpkgs = { config?; overlays?; }
          nixpkgs ? { },
          # nixos = { modules?; specialArgs?; }
          nixos ? { },
          # home = { modules?; specialArgs?; embed?; useGlobalPkgs?; }
          home ? { },
          # outputs = { extra?; disabled?; expected?; }
          outputs ? { },
          ...
        }:
        let
          # 解析嵌套命名空间，与扁平参数合并（嵌套命名空间优先）。
          # 扁平参数通过 args_raw 读取，避免 let 递归绑定遮蔽同名参数。
          flatOr = name: default: if builtins.hasAttr name args_raw then args_raw.${name} else default;

          nixpkgsConfig =
            if builtins.hasAttr "config" nixpkgs then nixpkgs.config else flatOr "nixpkgsConfig" { };
          extraOverlays =
            if builtins.hasAttr "overlays" nixpkgs then nixpkgs.overlays else flatOr "extraOverlays" [ ];
          legacySpecialArgs = flatOr "extraSpecialArgs" { };
          extraSpecialArgs =
            if builtins.hasAttr "specialArgs" nixos then nixos.specialArgs else legacySpecialArgs;
          extraHomeSpecialArgs =
            if builtins.hasAttr "specialArgs" home then home.specialArgs else legacySpecialArgs;
          # extraModules 同时注入 NixOS 与 HM 两侧；分组参数按侧注入。
          extraModules = flatOr "extraModules" [ ];
          extraNixosModules =
            if builtins.hasAttr "modules" nixos then nixos.modules else flatOr "extraNixosModules" [ ];
          extraHomeModules =
            if builtins.hasAttr "modules" home then home.modules else flatOr "extraHomeModules" [ ];
          embedHomeManager =
            if builtins.hasAttr "embed" home then home.embed else flatOr "embedHomeManager" true;
          homeManagerUseGlobalPkgs =
            if builtins.hasAttr "useGlobalPkgs" home then
              home.useGlobalPkgs
            else
              flatOr "homeManagerUseGlobalPkgs" true;
          extraOutputs =
            if builtins.hasAttr "extra" outputs then outputs.extra else flatOr "extraOutputs" { };
          disabledOutputs =
            if builtins.hasAttr "disabled" outputs then outputs.disabled else flatOr "disabledOutputs" [ ];
          expectedOutputs =
            if builtins.hasAttr "expected" outputs then outputs.expected else flatOr "expectedOutputs" { };
          homesStandalone =
            if builtins.hasAttr "homes" outputs && builtins.hasAttr "standalone" outputs.homes then
              outputs.homes.standalone
            else
              true;
          evalOutputs = outputs.eval or { };
          diagnosticsOutputs = outputs.diagnostics or { };
          packageSystems = lib.unique (systems ++ map (host: host.system) discovered.hosts);
          pkgsBySystem = lib.genAttrs packageSystems (
            system:
            pkgsFor {
              inherit system nixpkgsConfig extraOverlays;
            }
          );

          nixosConfigurations = lib.listToAttrs (
            map (
              h:
              lib.nameValuePair h.name (mkSystem {
                host = h.name;
                inherit (h) system;
                inherit
                  extraSpecialArgs
                  extraHomeSpecialArgs
                  extraModules
                  extraNixosModules
                  extraHomeModules
                  nixpkgsConfig
                  extraOverlays
                  embedHomeManager
                  homeManagerUseGlobalPkgs
                  ;
                hostPackages = hostPackagesFor h.name h.system;
              })
            ) discovered.hosts
          );

          disabledSet = validationTools.parseDisabledOutputs { inherit disabledOutputs; };

          disabledByName =
            kind: name:
            validationTools.isDisabledByName {
              inherit kind name disabledOutputs disabledSet;
            };

          disabledForSystem =
            kind: name: system:
            validationTools.isDisabledForSystem {
              inherit kind name system disabledOutputs disabledSet disabledByName;
            };

          metadataEnabled =
            args:
            outputTools.metadataEnabled (args // { inherit disabledForSystem; });

          uniqueDefinitions = outputTools.uniqueDefinitions;

          knownSystems = lib.unique (systems ++ lib.systems.flakeExposed);
          knownSystemsSet = lib.genAttrs knownSystems (_: true);
          packageDefs = map (
            package:
            let
              parts = lib.splitString "." package.name;
              suffix = lib.last parts;
              hasExplicitMetadata = package.meta ? systems;
              legacySystem =
                if
                  package.explicitSystem == null && !hasExplicitMetadata && builtins.hasAttr suffix knownSystemsSet
                then
                  suffix
                else
                  null;
              name = if legacySystem == null then package.name else lib.concatStringsSep "." (lib.init parts);
              supportedSystems =
                if package.explicitSystem != null then
                  [ package.explicitSystem ]
                else if hasExplicitMetadata then
                  package.meta.systems
                else if legacySystem != null then
                  [ legacySystem ]
                else
                  null;
            in
            package
            // {
              inherit name supportedSystems;
              meta = package.meta // lib.optionalAttrs (supportedSystems != null) { systems = supportedSystems; };
            }
          ) discovered.packages;

          hostPackagesFor =
            host: system:
            map (package: package // { scope = hostPlans.${host}.metadata.packages.${package.name}.scope; }) (
              lib.filter (
                package:
                (package.explicitSystem == null || package.explicitSystem == system)
                && metadataEnabled {
                  kind = "packages";
                  inherit (package) name meta;
                  inherit system;
                }
                && (hostPlans.${host}.metadata.packages.${package.name}.enable or false)
              ) packageDefs
            );

          packages = forAllSystems systems (
            sys:
            let
              pkgs = pkgsBySystem.${sys};
              definitions = uniqueDefinitions "packages" sys (
                lib.filter (
                  package:
                  (package.explicitSystem == null || package.explicitSystem == sys)
                  && metadataEnabled {
                    kind = "packages";
                    inherit (package) name meta;
                    system = sys;
                  }
                ) packageDefs
              );
            in
            lib.listToAttrs (map (p: lib.nameValuePair p.name (callPackage pkgs p.path)) definitions)
          );

          namedSystemOutputs =
            kind: definitions:
            outputTools.namedSystemOutputs {
              inherit
                lib
                kind
                systems
                definitions
                metadataEnabled
                uniqueDefinitions
                callPackage
                pkgsBySystem
                ;
            };

          devShells = namedSystemOutputs "devShells" discovered.shells;
          discoveredChecks = namedSystemOutputs "checks" discovered.checks;
          apps = namedSystemOutputs "apps" discovered.apps;
          appsEnabled = lib.any (sys: apps.${sys} != { }) systems;

          formatter = lib.listToAttrs (
            lib.concatMap (
              sys:
              if
                discovered.formatter != null
                && metadataEnabled {
                  kind = "formatter";
                  name = "default";
                  inherit (discovered.formatter) meta;
                  system = sys;
                }
              then
                let
                  pkgs = pkgsBySystem.${sys};
                in
                [ (lib.nameValuePair sys (callPackage pkgs discovered.formatter.path)) ]
              else
                [ ]
            ) systems
          );

          deployEnabled =
            discovered.deploy != null
            && metadataEnabled {
              kind = "deploy";
              name = "default";
              inherit (discovered.deploy) meta;
              system = lib.head systems;
            };
          deploy = importFile discovered.deploy.path;

          userLib = lib.listToAttrs (
            map (
              f: lib.nameValuePair (lib.removeSuffix ".nix" f.name) (importFile (projectRoot + "/lib/" + f.name))
            ) discovered.libFiles
          );

          homeConfigurations =
            let
              global = lib.listToAttrs (
                map (
                  h:
                  lib.nameValuePair h.user (mkHome {
                    inherit (h) user;
                    system = lib.head systems;
                    extraSpecialArgs = extraHomeSpecialArgs;
                    inherit
                      extraModules
                      extraHomeModules
                      nixpkgsConfig
                      extraOverlays
                      ;
                    _pkgs = pkgsBySystem.${lib.head systems};
                  })
                ) (lib.filter (homeRecord: homeRecord.defaultPath != null) discovered.homes)
              );
              perHost = lib.listToAttrs (
                lib.concatMap (
                  h:
                  map (
                    host:
                    lib.nameValuePair "${h.user}@${host}" (mkHome {
                      inherit (h) user;
                      extraSpecialArgs = extraHomeSpecialArgs;
                      inherit
                        host
                        extraModules
                        extraHomeModules
                        nixpkgsConfig
                        extraOverlays
                        ;
                      hostPackages = hostPackagesFor host discovered.hostsByName.${host}.system;
                    })
                  ) (lib.filter (host: builtins.hasAttr host discovered.hostsByName) h.hosts)
                ) discovered.homes
              );
            in
            if homesStandalone then global // perHost else perHost;

          images = lib.mapAttrs (
            host: cfg:
            let
              hostRec = hostMeta.resolveHost host;
              fmts = hostRec.meta.images.formats or [ ];
              avail = cfg.config.system.build.images;
            in
            lib.genAttrs fmts (
              f:
              if builtins.hasAttr f avail then
                avail.${f}
              else
                throw "error: image format not supported

  host '${host}' requested image format '${f}'
  but this format is not available in the current nixpkgs
  hint: check available formats with 'nixos-rebuild help-images'"
            )
          ) nixosConfigurations;

          # Validation calls that don't depend on system — lift to top level to avoid
          # redundant execution across systems
          _validatedExpected = validationTools.validateExpectedOutputs { inherit expectedOutputs; };
          expectedMode = _validatedExpected.expectedMode;
          checkedExpectedFields = _validatedExpected.checkedExpectedFields;
          supportedExpectedFields = _validatedExpected.supportedExpectedFields;

          checkedEvalOutputs = validationTools.validateEvalOutputs { inherit evalOutputs; };
          evalHosts = checkedEvalOutputs.hosts or false;
          evalHomes = checkedEvalOutputs.homes or false;

          diagnostics = validationTools.validateDiagnostics { inherit diagnosticsOutputs; };
          checkedDiagnostics = builtins.deepSeq diagnostics true;

          systemsSet = lib.genAttrs systems (_: true);
          buildChecksForSystem =
            sys:
            let
              pkgs = pkgsBySystem.${sys};
              discoveredHosts = map (host: host.name) discovered.hosts;
              discoveredHomes = builtins.attrNames homeConfigurations;
              discoveredPkgs = builtins.attrNames packages.${sys};
              discoveredApps = if appsEnabled then builtins.attrNames apps.${sys} else [ ];
              discoveredShells = builtins.attrNames devShells.${sys};
              discoveredUserChecks = builtins.attrNames discoveredChecks.${sys};
              discoveredOverlays = builtins.attrNames overlays;
              discoveredNixosModules = builtins.attrNames discovered.localGroupedModules.nixos;
              discoveredHomeModules = builtins.attrNames discovered.localGroupedModules.home;
              discoveredFormatter = lib.optional (builtins.hasAttr sys formatter) sys;
              discoveredDeploy =
                lib.optional deployEnabled "present"
                ++ lib.optionals (
                  deployEnabled && builtins.isAttrs deploy && builtins.isAttrs (deploy.nodes or null)
                ) (map (name: "nodes.${name}") (builtins.attrNames deploy.nodes));
              discoveredImages = lib.concatMap (
                hostRecord: map (format: "${hostRecord.name}.${format}") (hostRecord.meta.images.formats or [ ])
              ) discovered.hosts;

              stringList =
                label: value:
                if builtins.isList value && lib.all builtins.isString value then
                  lib.unique value
                else
                  throw "outputs.expected.${label} must be a list of strings";
              perSystemExpected =
                kind: value:
                if builtins.isList value then
                  stringList kind value
                else if builtins.isAttrs value then
                  let
                    unknownSystems = lib.filter (system: !builtins.hasAttr system systemsSet) (
                      builtins.attrNames value
                    );
                    validated = lib.mapAttrs (system: items: stringList "${kind}.${system}" items) value;
                  in
                  if unknownSystems != [ ] then
                    throw "outputs.expected.${kind} contains unconfigured systems: ${lib.concatStringsSep ", " unknownSystems}"
                  else
                    builtins.deepSeq validated (validated.${sys} or [ ])
                else
                  throw "outputs.expected.${kind} must be a list of strings or an attrset mapping systems to lists of strings";
              formatterExpected =
                value:
                let
                  configured = stringList "formatter" value;
                  unknownSystems = lib.filter (system: !builtins.hasAttr system systemsSet) configured;
                in
                if unknownSystems != [ ] then
                  throw "outputs.expected.formatter contains unconfigured systems: ${lib.concatStringsSep ", " unknownSystems}"
                else
                  lib.filter (system: system == sys) configured;
              deployExpected =
                value:
                if !builtins.isAttrs value then
                  throw "outputs.expected.deploy must be an attribute set"
                else
                  let
                    present = value.present or false;
                    nodes = stringList "deploy.nodes" (value.nodes or [ ]);
                  in
                  if !builtins.isBool present then
                    throw "outputs.expected.deploy.present must be a boolean"
                  else
                    lib.optional present "present" ++ map (name: "nodes.${name}") nodes;
              imagesExpected =
                value:
                if !builtins.isAttrs value then
                  throw "outputs.expected.images must be an attrset mapping hosts to lists of image formats"
                else
                  lib.concatLists (
                    lib.mapAttrsToList (
                      host: formats: map (format: "${host}.${format}") (stringList "images.${host}" formats)
                    ) value
                  );
              expectedFor =
                kind:
                let
                  value =
                    checkedExpectedFields.${kind} or (
                      if
                        builtins.hasAttr kind {
                          deploy = true;
                          images = true;
                        }
                      then
                        { }
                      else
                        [ ]
                    );
                in
                if
                  builtins.hasAttr kind {
                    packages = true;
                    apps = true;
                    checks = true;
                    devShells = true;
                  }
                then
                  perSystemExpected kind value
                else if kind == "formatter" then
                  formatterExpected value
                else if kind == "deploy" then
                  deployExpected value
                else if kind == "images" then
                  imagesExpected value
                else
                  stringList kind value;
              actualFor = {
                hosts = discoveredHosts;
                homes = discoveredHomes;
                packages = discoveredPkgs;
                apps = discoveredApps;
                checks = discoveredUserChecks;
                devShells = discoveredShells;
                overlays = discoveredOverlays;
                nixosModules = discoveredNixosModules;
                homeModules = discoveredHomeModules;
                formatter = discoveredFormatter;
                deploy = discoveredDeploy;
                images = discoveredImages;
              };
              kindsToCheck =
                if expectedMode == "exact" then
                  supportedExpectedFields
                else
                  builtins.attrNames checkedExpectedFields;
              checkExpected =
                kind:
                let
                  expected = lib.unique (expectedFor kind);
                  actual = lib.unique actualFor.${kind};
                  actualSet = lib.genAttrs actual (_: true);
                  expectedSet = lib.genAttrs expected (_: true);
                  missing = sortNames (lib.filter (item: !builtins.hasAttr item actualSet) expected);
                  unexpected =
                    if expectedMode == "exact" then
                      sortNames (lib.filter (item: !builtins.hasAttr item expectedSet) actual)
                    else
                      [ ];
                  script = pkgs.writeShellScript "check-discovery-${kind}-${sys}" ''
                    set -euo pipefail
                    missing=${lib.escapeShellArg (builtins.toJSON missing)}
                    unexpected=${lib.escapeShellArg (builtins.toJSON unexpected)}
                    if [ "$missing" != "[]" ]; then
                      echo "snowveil-discovery: outputs.expected.${kind} is missing the following entries:" >&2
                      echo "$missing" | ${pkgs.jq}/bin/jq -r '.[]' | sed 's/^/  - /' >&2
                    fi
                    if [ "$unexpected" != "[]" ]; then
                      echo "snowveil-discovery: outputs.expected.${kind} contains the following unexpected entries:" >&2
                      echo "$unexpected" | ${pkgs.jq}/bin/jq -r '.[]' | sed 's/^/  - /' >&2
                    fi
                    if [ "$missing" != "[]" ] || [ "$unexpected" != "[]" ]; then
                      exit 1
                    fi
                    touch "$out"
                  '';
                in
                pkgs.runCommand "snowveil-discovery-check-${kind}-${sys}" { } "bash ${script}";
              expectedChecks = lib.listToAttrs (
                map (
                  kind: lib.nameValuePair "snowveil-discovery-expected-${kind}" (checkExpected kind)
                ) kindsToCheck
              );

              selectedEvalHosts = validationTools.stringListOrBool {
                label = "hosts";
                value = evalHosts;
                available = discoveredHosts;
              };
              selectedEvalHomes = validationTools.stringListOrBool {
                label = "homes";
                value = evalHomes;
                available = discoveredHomes;
              };
              checkedEval = builtins.deepSeq selectedEvalHosts (builtins.deepSeq selectedEvalHomes true);
              selectedEvalHostSet = lib.genAttrs selectedEvalHosts (_: true);
              hostEvalRecords =
                map
                  (hostRecord: {
                    inherit (hostRecord) name;
                    drvPath =
                      builtins.unsafeDiscardStringContext
                        nixosConfigurations.${hostRecord.name}.config.system.build.toplevel.drvPath;
                  })
                  (
                    lib.filter (
                      hostRecord: hostRecord.system == sys && builtins.hasAttr hostRecord.name selectedEvalHostSet
                    ) discovered.hosts
                  );
              systemForHome =
                name:
                if lib.hasInfix "@" name then
                  discovered.hostsByName.${lib.last (lib.splitString "@" name)}.system
                else
                  lib.head systems;
              homeEvalRecords = map (name: {
                inherit name;
                drvPath = builtins.unsafeDiscardStringContext homeConfigurations.${name}.activationPackage.drvPath;
              }) (lib.filter (name: systemForHome name == sys) selectedEvalHomes);
              evalChecks =
                assert checkedEval;
                lib.optionalAttrs (evalHosts == true || hostEvalRecords != [ ]) {
                  snowveil-eval-hosts = pkgs.writeText "snowveil-eval-hosts-${sys}.json" (
                    builtins.toJSON hostEvalRecords
                  );
                }
                // lib.optionalAttrs (evalHomes == true || homeEvalRecords != [ ]) {
                  snowveil-eval-homes = pkgs.writeText "snowveil-eval-homes-${sys}.json" (
                    builtins.toJSON homeEvalRecords
                  );
                };

              graphReport = lib.mapAttrs (_: graph: {
                inherit (graph)
                  order
                  edges
                  groups
                  capabilities
                  ;
                nodes = builtins.attrNames graph.nodes;
                details = lib.mapAttrs (_: node: {
                  inherit (node)
                    requires
                    requiresGroups
                    provides
                    requiresCapabilities
                    after
                    before
                    wants
                    conflicts
                    ;
                }) graph.nodes;
              }) discovered.moduleGraph;
              perHostReport =
                if diagnostics.perHostModuleGraph then
                  builtins.listToAttrs (
                    map (
                      hostRecord: lib.nameValuePair hostRecord.name (moduleReportForHost hostRecord)
                    ) discovered.hosts
                  )
                else
                  { };
              report = {
                schemaVersion = 1;
                discoverySpecVersion = "1.3";
                frameworkVersion = version.string;
                system = sys;
                hosts = discoveredHosts;
                hostFiles = builtins.listToAttrs (
                  map (
                    hostRecord: lib.nameValuePair hostRecord.name (map baseNameOf hostRecord.modulePaths)
                  ) discovered.hosts
                );
                inherit (discovered) profiles;
                hostProfiles = builtins.listToAttrs (
                  map (
                    hostRecord: lib.nameValuePair hostRecord.name hostPlans.${hostRecord.name}.profiles
                  ) discovered.hosts
                );
                homes = discoveredHomes;
                packages = discoveredPkgs;
                apps = discoveredApps;
                checks = discoveredUserChecks;
                devShells = discoveredShells;
                overlays = discoveredOverlays;
                nixosModules = discoveredNixosModules;
                homeModules = discoveredHomeModules;
                formatter = discoveredFormatter;
                deploy = discoveredDeploy;
                images = discoveredImages;
                moduleGraph = graphReport;
                perHost = perHostReport;
              };

              dotEscape = value: builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] value;
              dotFor =
                name: nodes: edges:
                let
                  selected = sortNames nodes;
                  selectedSet = lib.genAttrs selected (_: true);
                  selectedEdges = lib.filter (
                    edge: builtins.hasAttr edge.from selectedSet && builtins.hasAttr edge.to selectedSet
                  ) edges;
                  nodeLines = map (node: "  \"${dotEscape node}\";") selected;
                  edgeLines = map (
                    edge: "  \"${dotEscape edge.to}\" -> \"${dotEscape edge.from}\" [label=\"${dotEscape edge.kind}\"];"
                  ) selectedEdges;
                in
                lib.concatStringsSep "\n" (
                  [
                    "digraph \"${dotEscape name}\" {"
                    "  rankdir=LR;"
                  ]
                  ++ nodeLines
                  ++ edgeLines
                  ++ [ "}" ]
                )
                + "\n";
              globalDotFiles =
                lib.concatMap
                  (side: [
                    {
                      path = "${side}.dot";
                      text = dotFor side (builtins.attrNames
                        discovered.moduleGraph.${side}.nodes
                      ) discovered.moduleGraph.${side}.edges;
                    }
                  ])
                  [
                    "nixos"
                    "home"
                  ];
              hostDotFiles = lib.concatMap (
                host:
                lib.concatMap
                  (
                    side:
                    let
                      hostSide = perHostReport.${host}.${side};
                    in
                    [
                      {
                        path = "hosts/${host}/${side}.dot";
                        text = dotFor "${host}-${side}" hostSide.enabled (
                          discovered.moduleGraph.${side}.edges ++ hostSide.capabilityEdges
                        );
                      }
                    ]
                  )
                  [
                    "nixos"
                    "home"
                  ]
              ) (builtins.attrNames perHostReport);
              dotFiles = globalDotFiles ++ hostDotFiles;
              dotCheck =
                pkgs.runCommand "snowveil-module-graph-dot-${sys}" { nativeBuildInputs = [ pkgs.graphviz ]; }
                  ''
                    export HOME="$TMPDIR"
                    export XDG_CACHE_HOME="$TMPDIR/.cache"
                    export FONTCONFIG_FILE=${pkgs.fontconfig.out}/etc/fonts/fonts.conf
                    mkdir -p "$XDG_CACHE_HOME/fontconfig"
                    mkdir -p "$out"
                    ${lib.concatMapStringsSep "\n" (
                      file:
                      let
                        sourceFile = pkgs.writeText (baseNameOf file.path) file.text;
                        svgPath = lib.removeSuffix ".dot" file.path + ".svg";
                      in
                      ''
                        mkdir -p "$out/${builtins.dirOf file.path}"
                        cp ${sourceFile} "$out/${file.path}"
                        dot -Tsvg ${sourceFile} > "$out/${svgPath}"
                      ''
                    ) dotFiles}
                  '';

              doctorFindings =
                let
                  hasHomeManager = inputs ? home-manager;
                  hostsWithHomes = lib.filter (host: (discovered.usersByHost.${host} or [ ]) != [ ]) (
                    builtins.attrNames discovered.hostsByName
                  );
                  disabledUnusedByAny =
                    let
                      sideReport =
                        side:
                        let
                          enabledUnion = lib.unique (
                            lib.concatMap (host: hostPlans.${host}.${side}.order) (builtins.attrNames discovered.hostsByName)
                          );
                          allNames = builtins.attrNames discovered.moduleGraph.${side}.nodes;
                        in
                        lib.filter (name: !builtins.elem name enabledUnion) allNames;
                    in
                    {
                      nixos = sideReport "nixos";
                      home = sideReport "home";
                    };
                  findings =
                    lib.optionals (!hasHomeManager && hostsWithHomes != [ ]) [
                      {
                        severity = "error";
                        kind = "missing_home_manager_input";
                        message = "hosts ${lib.concatStringsSep ", " hostsWithHomes} have associated homes but no home-manager input is wired; add home-manager to flake inputs";
                      }
                    ]
                    ++
                      lib.concatMap
                        (
                          side:
                          map (name: {
                            severity = "warning";
                            kind = "unused_module";
                            message = "${side} module '${name}' is defined but not enabled by any host";
                          }) disabledUnusedByAny.${side}
                        )
                        [
                          "nixos"
                          "home"
                        ];
                in
                {
                  schemaVersion = 1;
                  system = sys;
                  frameworkVersion = version.string;
                  ok = findings == [ ] || lib.all (finding: finding.severity != "error") findings;
                  counts = {
                    error = builtins.length (lib.filter (f: f.severity == "error") findings);
                    warning = builtins.length (lib.filter (f: f.severity == "warning") findings);
                  };
                  findings = lib.sort (a: b: a.kind < b.kind || (a.kind == b.kind && a.message < b.message)) findings;
                };
              doctorReportJson = builtins.toJSON doctorFindings;
              doctorReportText = pkgs.writeText "snowveil-doctor-${sys}.txt" (
                if doctorFindings.findings == [ ] then
                  "snowveil-doctor (${sys}): all clear\n"
                else
                  lib.concatStringsSep "\n" (
                    [
                      "snowveil-doctor (${sys})"
                      "errors: ${toString doctorFindings.counts.error}, warnings: ${toString doctorFindings.counts.warning}"
                      ""
                    ]
                    ++ map (f: "  [${f.severity}] ${f.kind}: ${f.message}") doctorFindings.findings
                  )
                  + "\n"
              );
              doctorCheck = pkgs.runCommand "snowveil-doctor-${sys}" { } ''
                mkdir -p "$out"
                cp ${pkgs.writeText "snowveil-doctor-${sys}.json" doctorReportJson} "$out/report.json"
                cp ${doctorReportText} "$out/report.txt"
                ${lib.optionalString (!doctorFindings.ok) ''
                  cat "$out/report.txt" >&2
                  echo "snowveil-doctor: ${toString doctorFindings.counts.error} error(s) detected" >&2
                  exit 1
                ''}
              '';

              renderNix =
                value:
                if builtins.isBool value then
                  if value then "true" else "false"
                else if builtins.isString value then
                  builtins.toJSON value
                else if builtins.isList value then
                  "[ ${lib.concatMapStringsSep " " renderNix value} ]"
                else if builtins.isAttrs value then
                  "{\n${
                    lib.concatMapStringsSep "" (name: "  ${builtins.toJSON name} = ${renderNix value.${name}};\n") (
                      builtins.attrNames value
                    )
                  }}"
                else
                  throw "cannot render outputs.expected scaffold value of type ${builtins.typeOf value}";
              expectedScaffold = {
                mode = "exact";
                hosts = discoveredHosts;
                homes = discoveredHomes;
                packages = lib.genAttrs systems (system: builtins.attrNames packages.${system});
                apps = lib.genAttrs systems (
                  system: if appsEnabled then builtins.attrNames apps.${system} else [ ]
                );
                checks = lib.genAttrs systems (system: builtins.attrNames discoveredChecks.${system});
                devShells = lib.genAttrs systems (system: builtins.attrNames devShells.${system});
                overlays = discoveredOverlays;
                nixosModules = discoveredNixosModules;
                homeModules = discoveredHomeModules;
                formatter = builtins.attrNames formatter;
                deploy = {
                  present = deployEnabled;
                  nodes =
                    if deployEnabled && builtins.isAttrs deploy && builtins.isAttrs (deploy.nodes or null) then
                      builtins.attrNames deploy.nodes
                    else
                      [ ];
                };
                images = builtins.listToAttrs (
                  map (
                    hostRecord: lib.nameValuePair hostRecord.name (hostRecord.meta.images.formats or [ ])
                  ) discovered.hosts
                );
              };
              expectedScaffoldCheck = pkgs.writeText "snowveil-expected-scaffold-${sys}.nix" ''
                outputs.expected = ${renderNix expectedScaffold};
              '';

              coverageHosts = lib.filter (hostRecord: hostRecord.system == sys) discovered.hosts;
              coverageForSide =
                side:
                let
                  allModules = builtins.attrNames discovered.moduleGraph.${side}.nodes;
                  total = builtins.length allModules;
                  hosts = builtins.listToAttrs (
                    map (
                      hostRecord:
                      let
                        enabled = hostPlans.${hostRecord.name}.${side}.order;
                        enabledCount = builtins.length enabled;
                      in
                      lib.nameValuePair hostRecord.name {
                        inherit enabled total;
                        disabled = lib.filter (name: !builtins.elem name enabled) allModules;
                        percent = if total == 0 then 100 else builtins.div (enabledCount * 100) total;
                      }
                    ) coverageHosts
                  );
                in
                {
                  inherit total hosts;
                  modules = lib.genAttrs allModules (
                    name:
                    let
                      enabledBy = map (hostRecord: hostRecord.name) (
                        lib.filter (hostRecord: builtins.elem name hostPlans.${hostRecord.name}.${side}.order) coverageHosts
                      );
                    in
                    {
                      inherit enabledBy;
                      hostCount = builtins.length enabledBy;
                    }
                  );
                };
              moduleCoverageReport = {
                schemaVersion = 1;
                system = sys;
                frameworkVersion = version.string;
                hostCount = builtins.length coverageHosts;
                sides = lib.genAttrs [ "nixos" "home" ] coverageForSide;
              };
              moduleCoverageCheck = pkgs.writeText "snowveil-module-coverage-${sys}.json" (
                builtins.toJSON moduleCoverageReport
              );

              reservedCollision = lib.findFirst (name: lib.hasPrefix "snowveil-" name) null discoveredUserChecks;
            in
            if reservedCollision != null then
              throw ''
                reserved output name

                'checks.${reservedCollision}' uses the framework-reserved snowveil- prefix
                hint: use a different name for your check
              ''
            else
              assert checkedDiagnostics;
              discoveredChecks.${sys}
              // expectedChecks
              // evalChecks
              // lib.optionalAttrs diagnostics.discovery {
                snowveil-discovery = pkgs.writeText "snowveil-discovery-${sys}.json" (builtins.toJSON report);
              }
              // lib.optionalAttrs diagnostics.moduleGraph {
                snowveil-module-graph-dot = dotCheck;
              }
              // lib.optionalAttrs diagnostics.doctor {
                snowveil-doctor = doctorCheck;
              }
              // lib.optionalAttrs diagnostics.expectedScaffold {
                snowveil-expected-scaffold = expectedScaffoldCheck;
              }
              // lib.optionalAttrs diagnostics.moduleCoverage {
                snowveil-module-coverage = moduleCoverageCheck;
              };

          checks = forAllSystems systems buildChecksForSystem;
          moduleOutput = paths: { imports = paths; };

          # Flake output schema: 标准 outputs 复用 flake-schemas，
          # 补充 Snowveil 专属的 images / deploy / options。
          schemas = (inputs.flake-schemas or { }).exportedSchemas or { } // schema.snowveilSchemas;

          generated = {
            inherit
              nixosConfigurations
              homeConfigurations
              packages
              devShells
              checks
              overlays
              images
              schemas
              ;
            lib = userLib;
            nixosModules = lib.mapAttrs (_: moduleOutput) discovered.localGroupedModules.nixos;
            homeModules = lib.mapAttrs (_: moduleOutput) discovered.localGroupedModules.home;
          }
          // lib.optionalAttrs appsEnabled { inherit apps; }
          // lib.optionalAttrs (discovered.formatter != null && formatter != { }) { inherit formatter; }
          // lib.optionalAttrs deployEnabled { inherit deploy; };
        in
        lib.recursiveUpdate generated extraOutputs;
    in
    {
      inherit
        mkFlake
        mkSystem
        mkHome
        forAllSystems
        version
        tests
        ;
      inherit (fs) importModules flattenTree groupModules;
      inherit
        patches
        source
        projectSource
        ;
      sops = sops';
    };

  mkLib = { inputs }: bind { inherit inputs; };

  mkFlake =
    args@{ inputs, ... }:
    let
      inputsPos = builtins.unsafeGetAttrPos "inputs" args;
      root =
        args.root or (if inputsPos != null then builtins.dirOf inputsPos.file else inputs.self.outPath);
    in
    (bind {
      inherit inputs root;
      moduleRegistries = args.moduleRegistries or [ ];
      moduleGroups = args.moduleGroups or { };
      profiles = args.profiles or { };
      sops = args.sops or { };
    }).mkFlake
      (
        builtins.removeAttrs args [
          "inputs"
          "moduleRegistries"
          "moduleGroups"
          "profiles"
          "root"
        ]
      );
in
{
  inherit
    mkLib
    mkFlake
    forAllSystems
    renderOptions
    version
    ;
  inherit (fs) importModules flattenTree groupModules;
  inherit patches;
  source = sourceTools;
  sops = import ./sops.nix;
}

{ lib }:

let
  # 默认排除项：VCS、环境与构建产物。node_modules/__pycache__ 同时列入 anyLevelDirs，
  # 以便任意层级的同名目录（如 docs/node_modules）整棵剪枝。
  defaultExcludes = [
    ".git"
    ".direnv"
    ".snowveil"
    "result"
    "node_modules"
    "__pycache__"
  ];

  # 任意层级剪枝的目录名：路径任一分段等于其中一项即排除。
  # 只按分段全名匹配，不误伤 node_modules.foo 之类的文件。
  anyLevelDirs = [
    "node_modules"
    "__pycache__"
    ".direnv"
  ];
  anyLevelSet = lib.listToAttrs (map (n: lib.nameValuePair n true) anyLevelDirs);

  normalize = value: lib.removePrefix "./" (lib.removeSuffix "/" value);
in
{
  clean =
    {
      root,
      excludes ? [ ],
      name ? "snowveil-project-source",
    }:
    let
      rootString = toString root;
      # 前缀排除保留原语义：exclude 项按相对路径前缀匹配（如 "docs"、"docs/sub"）。
      excluded = map normalize (defaultExcludes ++ excludes);
      isPrefixExcluded =
        relative: lib.any (item: relative == item || lib.hasPrefix "${item}/" relative) excluded;
      # 深层产物在首次触及其目录时即剪枝，builtins.path 不再遍历其内容。
      hasAnyLevelDir =
        relative: lib.any (segment: anyLevelSet ? ${segment}) (lib.splitString "/" relative);
      isExcluded = relative: hasAnyLevelDir relative || isPrefixExcluded relative;
    in
    builtins.path {
      path = root;
      inherit name;
      filter =
        path: _:
        let
          pathString = toString path;
          relative = lib.removePrefix "${rootString}/" pathString;
        in
        pathString == rootString || !isExcluded relative;
    };

  inherit defaultExcludes;
}

{ lib }:
{
  byMap = map: default: name:
    if builtins.hasAttr name map then
      map."${name}"
    else
      default;

  addPartitionIndex = drive: idx:
    if builtins.any (digit: lib.hasSuffix digit drive) (map toString [ 0 1 2 3 4 5 6 7 8 9 ]) then
      "${drive}p${toString idx}"
    else
      "${drive}${toString idx}";
}

{ nixpkgs, ... }:
{
  formatAssertions = assertions:
    let
      matchingAssertions = builtins.filter (a: a.condition) assertions;
      messages = map (a: a.message) matchingAssertions;

      formatSingleMessage = message:
        let
          lines = nixpkgs.lib.splitString "\n" message;
          firstLine = builtins.head lines;
          otherLines = builtins.tail lines;

          indented = map (line: "  ${line}") otherLines;
          sentinel = 
            if builtins.length otherLines == 0 then
              ""
            else
              "\n${builtins.concatStringsSep "\n" indented}";

          formatted = "- ${firstLine}${sentinel}";
        in
        if builtins.length lines == 0 then
          "- (No message given)"
        else
          formatted;
    in
    if builtins.length messages == 0 then
      null
    else
      builtins.concatStringsSep "\n" (map (formatSingleMessage) messages);
  
}

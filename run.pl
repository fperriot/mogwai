$target = $ARGV[0] || "target.exe";
open P, "susp \"$target\" |" or die;
$_ = <P>;
close P;
print;
($pid, $tid) = /process (\d+) . thread (\d+)/;
print `dllinjector ctrl.dll $pid`;
print "Hit <Return> to launch process";
getc;
system "conn $pid $tid";
system "\\tools\\pstools\\pskill $pid";


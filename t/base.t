# -*- perl -*-

print "1..2\n";

$@ = ''; eval { require HTML::EP; };
if ($@) { print "not "; } print "ok 1\n";

$@ = ''; eval { require Apache::EP; };
if ($@) { print "not "; } print "ok 2\n";

# -*- perl -*-

sub HaveModule ($) {
    my($module) = @_;
    $@ = '';
    eval "require $module";
    !$@;
}

print "1..2\n";

if (!HaveModule("HTML::EP")) { print "not "; }
print "ok 1\n";

if (!HaveModule("DBI")  ||  !HaveModule("Apache")) {
    print "ok 2 # Skip\n";
} else {
    if (!HaveModule("Apache::EP")) { print "not "; }
    print "ok 2\n";
}

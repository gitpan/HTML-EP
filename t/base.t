# -*- perl -*-

sub HaveModule ($) {
    my($module) = @_;
    $@ = '';
    eval "require $module";
    !$@;
}

print "1..7\n";

if (!HaveModule("HTML::EP")) { print "$@\nnot "; }
print "ok 1\n";

if (!HaveModule("DBI")  ||  !HaveModule("Apache")) {
    print "ok 2 # Skip\n";
} else {
    if (!HaveModule("Apache::EP")) { print "$@\nnot " }
    print "ok 2\n";
}

if (!HaveModule("HTML::EP::Locale")) { print "$@\nnot " }
print "ok 3\n";

if (!HaveModule("Storable")) {
    print "ok 4 # Skip\n";
    print "ok 5 # Skip\n";
    print "ok 6 # Skip\n";
} else {
    if (!HaveModule("HTML::EP::Session")) { print "$@\nnot " }
    print "ok 4\n";
    if (!HaveModule("HTML::EP::Shop")) { print "$@\nnot " }
    print "ok 5\n";
    if (!HaveModule("HTML::EP::Session::Cookie")) { print "$@\nnot " }
    print "ok 6\n";
}

if (!HaveModule("HTML::EP::Examples::Admin")) {
    print "$@\nnot ok 7\n";
} else {
    print "ok 7\n";
}

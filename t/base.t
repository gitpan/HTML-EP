# -*- perl -*-

sub HaveModule ($) {
    my($module) = @_;
    $@ = '';
    eval "require $module";
    !$@;
}

print "1..13\n";

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
if (!HaveModule("HTML::EP::Examples::Glimpse")) {
    print "$@\nnot ok 8\n";
} else {
    print "ok 8\n";
}
if (!HaveModule("Mail::POP3Client")) {
    print "ok 9 # Skip\n";
} elsif (!HaveModule("HTML::EP::Examples::POP3Client")) {
    print "$@\nnot ok 9\n";
} else {
    print "ok 9\n";
}
if (HaveModule("HTML::EP::Install")) {
    print "ok 10\n";
} else {
    print STDERR "$@\n";
    print "not ok 10\n";
}
if (HaveModule("DBI")) {
    if (HaveModule("HTML::EP::Session::DBI")) {
	print "ok 11\n";
    } else {
	print STDERR "$@\n";
	print "not ok 11\n";
    }
    if (HaveModule("HTML::EP::Session::DBIq")) {
	print "ok 12\n";
    } else {
	print STDERR "$@\n";
	print "not ok 12\n";
    }
} else {
    print "ok 11 # Skip\n";
    print "ok 12 # Skip\n";
}
if (HaveModule("HTML::EP::Session::Dumper")) {
    print "ok 13\n";
} else {
    print STDERR "$@\n";
    print "not ok 13\n";
}

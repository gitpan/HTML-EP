# -*- perl -*-
#
#   HTML::EP	- A Perl based HTML extension.
#
#
#   Copyright (C) 1998    Jochen Wiedmann
#                         Am Eisteich 9
#                         72555 Metzingen
#                         Germany
#
#                         Phone: +49 7123 14887
#                         Email: joe@ispsoft.de
#
#   All rights reserved.
#
#   You may distribute this module under the terms of either
#   the GNU General Public License or the Artistic License, as
#   specified in the Perl README file.
#
############################################################################


my $script = <<'END_OF_SCRIPT';
~startperl~
#
#   HTML::EP	- A Perl based HTML extension.
#
#
#   Copyright (C) 1998    Jochen Wiedmann
#                         Am Eisteich 9
#                         72555 Metzingen
#                         Germany
#
#                         Phone: +49 7123 14887
#                         Email: joe@ispsoft.de
#
#   All rights reserved.
#
#   You may distribute this module under the terms of either
#   the GNU General Public License or the Artistic License, as
#   specified in the Perl README file.
#
############################################################################

require 5.004;
use strict;


sub SimpleError ($$;$) {
    my $template = shift;
    my $errmsg = shift;
    my $admin = shift || $ENV{SERVER_ADMIN};
    if ($admin) {
	$admin = "<A HREF=\"mailto:$admin\">Webmaster</A>";
    } else {
	$admin = "Webmaster";
    }

    my $vars = { errmsg => $errmsg, admin => $admin };

    if (!$template) {
	$template = <<'END_OF_HTML';
<HTML><HEAD><TITLE>Fatal internal error</TITLE></HEAD>
<BODY><H1>Fatal internal error</H1>
<P>An internal error occurred. The error message is:</P>
<PRE>
$errmsg$.
</PRE>
<P>Please contact the $admin$ and tell him URL, time and error message.</P>
<P>We apologize for any inconvenience, please try again later.</P>
<BR><BR><BR>
<P>Yours sincerely</P>
</BODY></HTML>
END_OF_HTML
    }

    $template =~ s/\$(\w+)\$/$vars->{$1}/eg;
    print "content-type: text/html\n\n$template";
    exit 0;
}


my $self;
eval {
    require HTML::EP;
    require HTML::EP::Config;
    $SIG{'__WARN__'} = \&HTML::EP::WarnHandler;
    $self = HTML::EP->new();
};
if ($@) {
    SimpleError(undef, $@);
}
my $path = $ENV{'PATH_TRANSLATED'};
my $ok_templates = $HTML::EP::Config::CONFIGURATION->{'ok_templates'};
if ($ok_templates  &&  $path !~ /$ok_templates/) {
    die "Access to $path forbidden by ok_templates";
}
if ($path =~ /(.*)\//) {
    chdir $1;
}
my $cgi = $self->{'cgi'};
if ($cgi->param('debug')) {
    my $debughosts = $HTML::EP::Config::CONFIGURATION->{'debughosts'};
    if (!$debughosts  ||  $ENV{'REMOTE_ADDR'} =~ /$debughosts/) {
	$| = 1;
	print "content-type: text/plain\n\n";
	print "Entering debugging mode; list of input values:\n";
	my $p;
	foreach $p ($cgi->param()) {
	    print " $p = ", $cgi->param($p), "\n";
	}
	$self->{debug} = 1;
    } else {
	print STDERR ("Debugging not permitted from ", $ENV{'REMOTE_ADDR'},
		      ", restricted to $debughosts\n");
    }
}
my $output = eval { $self->Run(); };
if ($@) {
    if ($@ =~ /_ep_exit, ignore/) {
	$output = $self->{'_ep_output'};
    } else {
	my $errmsg;
	my $errstr = $@;
	my $errfile = $self->{_ep_err_type} ?
	    $self->{_ep_err_file_user} : $self->{_ep_err_file_system};
	if ($errfile) {
	    my $derrfile = $self->{'env'}->{'DOCUMENT_ROOT'} . $errfile;
	    if ($self->{'debug'}) {
		$self->print("Error type = " . $self->{_ep_err_type} .
			     ", error file = $errfile" .
			     ", derror file = $derrfile\n");
	    }
	    if (-f $derrfile) { $errfile = $derrfile }
	    eval {
		require Symbol;
		my $fh = Symbol::gensym();
		if (open($fh, "<$errfile")) {
		    local($/) = undef;
		    $errmsg = <$fh>;
		    close($fh);
		}
	    };
	}
	if (!$errmsg) {
	    $errmsg = $self->{_ep_err_type} ?
		$self->{_ep_err_msg_user} : $self->{_ep_err_msg_system};
	}
	SimpleError($errmsg, $errstr);
    }
}

if (!$self->{_ep_stop}) {
    print($cgi->header('-cookie' => [values %{$self->{'_ep_cookies'}}]),
	  $output);
}

exit 0;
END_OF_SCRIPT

require Config;
$script =~ s/\~startperl\~/$Config::Config{startperl}/e;
if (!open(FILE, ">ep.cgi")  ||  !print FILE ($script)  ||  !close(FILE)) {
    die "Error while creating 'ep.cgi': $!";
}

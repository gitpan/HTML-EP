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

require 5.004;
use strict;


require Apache;
require DBI;
require HTML::EP;
require Symbol;

# Pull in HTML::EP and the helper packages
require HTML::EP;
require HTML::EP::Locale;
require HTML::EP::Session;


package Apache::EP;

$Apache::EP::VERSION = '0.1003';

my $Is_Win32 = $^O eq "MSWin32";


sub SimpleError ($$$;$) {
    my($r, $template, $errmsg, $admin) = @_;
    if ($admin  ||  ($admin = $r->cgi_var('SERVER_ADMIN'))) {
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
    $r->send_http_header();
    $r->print($template);
}                                                                             


sub handler ($$) {
    my($class, $r) = @_;
    if(ref $r) {
	$r->request($r);
    } else {
	$r = Apache->request;
    }
    my $filename = $r->filename;
    local $^W;

    if (($r->allow_options() & Apache::Constants::OPT_EXECCGI())  ==  0) {
	$r->log_reason("Options ExecCGI is off in this directory",
		       $filename);
	return Apache::Constants::FORBIDDEN();
    }
    if (!-r $filename  ||  !-s _) {
	$r->log_reason("File not found", $filename);
	return Apache::Constants::NOT_FOUND();
    }
    if (-d _) {
	$r->log_reason("attempt to invoke directory as script", $filename);
	return Apache::Constants::FORBIDDEN();
    }

    $r->chdir_file($filename);
    $r->cgi_env('PATH_TRANSLATED' => $filename);
    my $self = HTML::EP->new();
    $self->{_ep_r} = $r;
    if ($self->{cgi}->param('debug')) {
	my $debughosts = $HTML::EP::Config::CONFIGURATION->{'debughosts'};
	my $c = $r->connection();
	if (!$debughosts  ||  $c->remote_ip() =~ /$debughosts/) {
	    $self->{'debug'} = 1;
	} else {
	    my $host = $r->get_remote_host();
	    if ($host =~ /$debughosts/) {
		$self->{'debug'} = 1;
	    } else {
		print STDERR "Debugging mode is restricted to $debughosts"
		    . " and not permitted from " . $c->remote_ip();
	    }
	}
    }
    if ($self->{'debug'}) {
	$r->content_type('text/plain');
	$r->status(Apache::Constants::OK());
	$r->send_http_header();
    } else {
	$r->content_type('text/html');
	$r->status(Apache::Constants::OK());
    }
    $r->no_cache(1);
    if ($self->{'debug'}) {
	$r->print("Entering debugging mode; list of input values:\n");
	my $p;
	foreach $p ($self->{cgi}->param()) {
	    $self->print(" $p = ", $self->{cgi}->param($p), "\n");
	}
	$self->{debug} = 1;                                 
    }
    local $SIG{'__WARN__'} = \&HTML::EP::WarnHandler;
    my $output = eval { $self->Run(); };
    if ($@) {
	if ($@ =~ /_ep_exit, ignore/) {
	    $output = $self->{'_ep_output'};
	} else {
	    my $errstr = $@;
	    my $errfile = $self->{_ep_err_type} ?
		$self->{_ep_err_file_user} : $self->{_ep_err_file_system};
	    my $errmsg;
	    my $derrfile = $self->{'env'}->{'DOCUMENT_ROOT'} . $errfile;
	    if (-f $derrfile) { $errfile = $derrfile }
	    if ($errfile) {
		eval {
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
	    SimpleError($r, $errmsg, $errstr);                     
	    return $r->status;
	}
    }
    if (!$self->{_ep_stop}) {
	$r->send_http_header();
	$r->print($output);
    }

    return $r->status;
}


1;

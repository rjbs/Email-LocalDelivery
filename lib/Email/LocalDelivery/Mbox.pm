package Email::LocalDelivery::Mbox;
use strict;

use File::Path;
use File::Basename;
use Email::Simple 1.998;  # needed for ->header_obj
use Fcntl ':flock';
use Symbol qw(gensym);

use vars qw($VERSION);
$VERSION = "1.103";

sub deliver {
  # The slightly convoluted method of unrolling the stack is intended to limit
  # the scope of which a large string at $_[1] might be in memory before being
  # constructed into an Email::Simple. -- rjbs, 2007-05-25
  my $class = shift;

  my $email;
  if (eval { $_[0]->isa('Email::Simple') }) {
    $email = shift;
  } else {
    my $text = shift;
    $email = Email::Simple->new(\$text); # requires Email::Simple 1.998 or so
  }

  my @files = @_;

  my @rv;

  for my $file (@files) {
    my $fh = $class->_open_fh($file) or next;
    print $fh "\n" if tell($fh) > 0;
    print $fh $class->_from_line($email);
    print $fh $class->_escape_from_body($email);

    # This will make streaming a bit more annoying. -- rjbs, 2007-05-25
    print $fh "\n" unless $email->as_string =~ /\n$/;

    $class->_close_fh($fh) || next;
    push @rv, $file;
  }
  return @rv;
}

sub _open_fh {
  my ($class, $file) = @_;
  my $dir = dirname($file);
  return if !-d $dir and not mkpath($dir);

  my $fh = gensym;
  open $fh, ">> $file" or return;
  $class->getlock($fh) || return;
  seek $fh, 0, 2;
  return $fh;
}

sub _close_fh {
  my ($class, $fh) = @_;
  $class->unlock($fh) || return;
  close $fh or return;
  return 1;
}

sub _escape_from_body {
  my ($class, $email) = @_;

  my $body = $email->body;
  $body =~ s/^(From )/>$1/gm;

  return $email->header_obj->as_string . $email->crlf . $body;
}

sub _from_line {
  my ($class, $email) = @_;

  # The qmail way.
  return $ENV{UFLINE} . $ENV{RPLINE} . $ENV{DTLINE} if exists $ENV{UFLINE};

  # The boring way.
  return _from_line_boring($email);
}

sub _from_line_boring {
  my $mail = shift;
  my $from = $mail->header("Return-path")
    || $mail->header("Sender")
    || $mail->header("Reply-To")
    || $mail->header("From")
    || 'root@localhost';
  $from = $1 if $from =~ /<(.*?)>/;  # comment <email@address> -> email@address
  $from =~ s/\s*\(.*\)\s*//;         # email@address (comment) -> email@address
  $from =~ s/\s+//g;                 # if any whitespace remains, get rid of it.

  my $fromtime = localtime;
  $fromtime =~ s/(:\d\d) \S+ (\d{4})$/$1 $2/;  # strip timezone.
  return "From $from  $fromtime\n";
}

sub getlock {
  my ($class, $fh) = @_;
  for (1 .. 10) {
    return 1 if flock($fh, LOCK_EX | LOCK_NB);
    sleep $_;
  }
  return 0;
}

sub unlock {
  my ($class, $fh) = @_;
  flock($fh, LOCK_UN);
}

1;

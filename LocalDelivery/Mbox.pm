package Email::LocalDelivery::Mbox;
use File::Path;
use File::Basename;
use Email::Simple;
use Fcntl ':flock';

our $VERSION = "1.07";

sub deliver {
    my ($class, $mail, @files) = @_;
    my @rv;
    for my $file (@files) {
        my $fh = $class->_open_fh($file) or next;
        print $fh "\n" if tell($fh) > 0;
        print $fh $class->_from_line(\$mail); # Avoid passing $mail where poss.
        print $fh $class->_escape_from_body(\$mail);
        print $fh "\n" unless $mail =~ /\n$/;
        $class->_close_fh($fh) || next;
        push @rv, $file
    }
    return @rv;
}

sub _open_fh {
    my ($class, $file) = @_;
    my $dir = dirname($file);
    return if ! -d $dir and not mkpath($dir);

    open my $fh, ">> $file" or return;
    $class->getlock($fh) || return;
    seek $fh, 0, 2;
    return $fh;
}

sub _close_fh {
    my ($class, $fh) = @_;
    $class->unlock($fh) || return;
    close $fh           or return;
    return 1;
}

sub _escape_from_body {
    my ($class, $mail_r) = @_;

    # breaking encapsulation is evil, but this routine is tricky
    my ($head, $body) = Email::Simple::_split_head_from_body($$mail_r);
    $body =~ s/^(From\s)/>$1/gm;

    return $$mail_r = "$head\n$body";
}

sub _from_line {
    my ($class, $mail_r) = @_;

    # The trivial way
    return if $$mail_r =~ /^From\s/;

    # The qmail way.
    return $ENV{UFLINE}.$ENV{RPLINE}.$ENV{DTLINE} if exists $ENV{UFLINE};

    # The boring way.
    return _from_line_boring(Email::Simple->new($$mail_r));
}

sub _from_line_boring {
    my $mail = shift;
    my $from = $mail->header("Return-path") ||
               $mail->header("Sender")      ||
               $mail->header("Reply-To")    ||
               $mail->header("From")        ||
               'root@localhost';
    $from = $1 if $from =~ /<(.*?)>/; # comment <email@address> -> email@address
    $from =~ s/\s*\(.*\)\s*//;        # email@address (comment) -> email@address
    $from =~ s/\s+//g; # if any whitespace remains, get rid of it.

    my $fromtime = localtime;
    $fromtime =~ s/(:\d\d) \S+ (\d{4})$/$1 $2/; # strip timezone.
    return "From $from  $fromtime\n";
}

sub getlock {
    my ($class, $fh) = @_;
    for (1..10) {
        return 1 if flock ($fh, LOCK_EX | LOCK_NB);
        sleep $_;
    }
    return 0 ;
}

sub unlock {
    my ($class,$fh) = @_;
    flock ($fh, LOCK_UN);
}

1;

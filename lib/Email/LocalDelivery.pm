use strict;
use warnings;
package Email::LocalDelivery;
# ABSTRACT: Deliver a piece of email - simply

use File::Path::Expand 1.01 qw(expand_filename);
use Email::FolderType 0.7 qw(folder_type);
use Carp;

=head1 SYNOPSIS

  use Email::LocalDelivery;
  my @delivered_to = Email::LocalDelivery->deliver($mail, @boxes);

=head1 DESCRIPTION

This module delivers an email to a list of mailboxes.

B<Achtung!>  You might be better off looking at L<Email::Sender>, and at
L<Email::Sender::Transport::Maildir> and L<Email::Sender::Transport::Mbox>.
They are heavily used and more carefully monitored.

=method deliver

This takes an email, as a plain string, and a list of mailboxes to
deliver that mail to. It returns the list of boxes actually written to.
If no boxes are given, it assumes the standard Unix mailbox. (Either
C<$ENV{MAIL}>, F</var/spool/mail/you>, F</var/mail/you>, or
F<~you/Maildir/>)

=cut

sub deliver {
    my ($class, $mail, @boxes) = @_;

    croak "Mail argument to deliver should just be a plain string"
        if ref $mail;

    if (!@boxes) {
        my $default_maildir = (getpwuid($>))[7] . "/Maildir/";
        my $default_unixbox
          = (grep { -d $_ } qw(/var/spool/mail/ /var/mail/))[0]
          . getpwuid($>);

        @boxes = $ENV{MAIL}
            || (-e $default_unixbox && $default_unixbox)
            || (-d $default_maildir."cur" && $default_maildir);
    }
    my %to_deliver;

    for my $box (@boxes) {
      $box = expand_filename($box);
      push @{$to_deliver{folder_type($box)}}, $box;
    }

    my @rv;
    for my $method (keys %to_deliver) {
        eval "require Email::LocalDelivery::$method";
        croak "Couldn't load a module to handle $method mailboxes" if $@;
        push @rv,
        "Email::LocalDelivery::$method"->deliver($mail,
                                                @{$to_deliver{$method}});
    }
    return @rv;
}

1;

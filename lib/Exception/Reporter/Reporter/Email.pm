use strict;
use warnings;
package Exception::Reporter::Reporter::Email;
# ABSTRACT: an exception reporter that sends detailed dumps via email

use Digest::MD5;
use Email::Address;
use Email::Date::Format qw(email_date);
use Email::MIME::Creator;
use Email::MessageID;
use Email::Sender::Simple;
use String::Truncate qw(elide);

use namespace::autoclean;

sub new {
  my ($class, $arg) = @_;

  my $from = $arg->{from} || Carp::confess("missing 'from' argument");
  my $to   = $arg->{to}   || Carp::confess("missing 'to' argument"),

  ($from) = Email::Address->parse($from);
  ($to)   = [ map {; Email::Address->parse($_) } (ref $to ? @$to : $to) ];

  # Allow mail from a simple, bare local-part like "root" -- rjbs, 2012-07-03
  $from = Email::Address->new(undef, $arg->{from})
    if ! $from and $arg->{from} =~ /\A[-.0-9a-zA-Z]+\z/;

  Carp::confess("couldn't interpret $arg->{from} as an email address")
    unless $from;

  my $env_from = $arg->{env_from} || $from->address;
  my $env_to   = $arg->{env_to}   || [ map {; $_->address } @$to ];

  $env_to = [ $env_to ] unless ref $env_to;

  return bless {
    from => $from,
    to   => $to,
    env_to   => $env_to,
    env_from => $env_from,
  }, $class;
}

sub from_header {
  my ($self) = @_;
  return $self->{from}->as_string;
}

sub to_header {
  my ($self) = @_;
  return join q{, }, map {; $_->as_string } @{ $self->{to} };
}

sub env_from {
  my ($self) = @_;
  return $self->{env_from};
}

sub env_to {
  my ($self) = @_;
  return @{ $self->{env_to} };
}

=head2 send_report

 $email_reporter->send_report(\@summaries, \%arg, \%internal_arg);

This method builds a multipart email message from the given summaries and
sends it.

C<%arg> is the same set of arguments given to Exception::Reporter's
C<report_exception> method.  Arguments that will have an effect include:

  extra_rcpts  - an arrayref of extra envelope recipients
  reporter     - the name of the program reporting the exception
  handled      - if true, the reported exception was handled and the user
                 saw a simple error message; sets X-Exception-Handled header
                 and adds a text part at the beginning of the report,
                 calling out the "handled" status"

C<%internal_arg> contains data produced by the Exception::Reporter using this
object.  It includes the C<guid> of the report and the C<caller> calling the
reporter.

The GUID is used in generating a message id.

All similar exceptions should have identical In-Reply-To headers, which can be
used to thread common exceptions together.

=cut

sub send_report {
  my ($self, $summaries, $arg, $internal_arg) = @_;

  my @parts;
  for my $summary (@$summaries) {
    my ($name) = split /\n/, $summary->{ident};

    push @parts, Email::MIME->create(
      ($summary->{body_is_bytes} ? 'body' : 'body_str') => $summary->{body},
      attributes => {
        # This ends up sometimes being awful when the ident is (say) a 40
        # character string with punctuation and so on.  Either we won't use
        # this, or we'll need a sanitizer. -- rjbs, 2012-07-03
        # name         => $name,

        filename     => $summary->{filename},
        content_type => $summary->{mimetype},
        encoding     => 'quoted-printable',

        ($summary->{body_is_bytes}
          ? ($summary->{charset} ? (charset => $summary->{charset}) : ())
          : (charset => $summary->{charset} || 'utf-8')),
      },
    );

    $parts[-1]->header_set(Date=>);
  }

  if ($arg->{handled}) {
    unshift @parts, Email::MIME->create(
      body_str   => "DON'T PANIC!\n"
                  . "THIS EXCEPTION WAS CAUGHT AND EXECUTION CONTINUED\n"
                  . "THIS REPORT IS PROVIDED FOR INFORMATIONAL PURPOSES\n",
      attributes => {
        content_type => "text/plain", # could be better
        charset      => 'utf-8',
        encoding     => 'quoted-printable',
        name         => 'prelude',
      },
    );
    $parts[-1]->header_set(Date=>);
  }

  my $ident = $summaries->[0] && $summaries->[0]->{ident}
           || "(unknown exception)";;

  (my $digest_ident = $ident) =~ s/\(.+//g;

  my ($package, $filename, $line) = @{ $internal_arg->{caller} };

  my $reporter = $arg->{reporter} || $package;

  my $email = Email::MIME->create(
    attributes => { content_type => 'multipart/mixed' },
    parts      => \@parts,
    header_str => [
      From => $self->from_header,
      To   => $self->to_header,
      Date => email_date,
      Subject      => elide("$reporter: $ident", 65),
      'X-Mailer'   => __PACKAGE__,
      'Message-Id' => Email::MessageID->new(user => $internal_arg->{guid})
                                      ->in_brackets,
      'In-Reply-To'=> Email::MessageID->new(
                        user => Digest::MD5::md5_hex($digest_ident),
                        host => $reporter,
                      )->in_brackets,
      'X-Exception-Reporter-Reporter' => "$filename line $line ($package)",
      'X-Exception-Reporter-Handled'  => ($arg->{handled} ? 1 : 0),
    ],
  );

  eval {
    Email::Sender::Simple->send(
      $email,
      {
        from    => $self->env_from,
        to      => [ $self->env_to ],
      }
    );
  };

  if ($@) {
    Carp::cluck "failed to send exception report: $@";
    return;
  }

  return;
}

1;

package Exception::Reporter::Reporter::Email;
use Moose;
# ABSTRACT: an exception reporter that sends detailed dumps via email

with 'Exception::Reporter::Role::Reporter';

use Digest::MD5;
use Email::Date::Format qw(email_date);
use Email::MIME::Creator;
use Email::MessageID;
use Email::Sender::Simple;
use String::Truncate qw(elide);
use YAML::XS qw(Dump);

use namespace::autoclean;

=head2 report_exception

  $reporter->send_exception_report($exception, $summary);

This method sends an exception report to the sysadmins.  It contains:

  * the exception
  * a YAML dump of the environment
  * a YAML dump of anything contained in the %dumpable hash

A GUID is used in generating a message id, and is returned by this method.

All similar exceptions should have identical In-Reply-To headers, which can be
used to thread common exceptions together.

Valid arguments are:

  reporter - the name of the program reporting the exception
  handled  - if true, the reported exception was handled and the user saw
             a simple error message; sets X-Exception-Handled header
             and adds a text part at the beginning of the report, calling out
             the "handled" status"

  extra_rcpts  - an arrayref of extra envelope recipients
  attach_files - an optional arrayref of files to attach; see below

Each entry in F<attach_files> must be a hashref.  Keys in this hashref may be:

  filename     - required
  description  - optional
  content_type - mime type; optional; defaults to application/unknown

=cut

sub report_exception {
  my ($self, $exception, $summary) = @_;

  $dumpable = $summary->{to_dump};

  # This belongs in a Summarizer. -- rjbs, 2010-10-26
  #
  # if (eval { $exception->isa('Exception::Class::Base') }) {
  #   $desc = eval { $exception->description . ': ' . $exception->error };
  #   $desc = "(no description)" unless defined $desc and length $desc;
  #   $error_string = eval { $exception->can('as_text') }
  #                 ? $exception->as_text # or else Mason $@ stringify to html
  #                 : $exception->as_string;
  # } else {

  my $summary = Email::MIME->create(
    body_str   => $fulltext,
    attributes => {
      filename     => 'exception.txt',
      content_type => 'text/plain',
      charset      => 'utf-8',
      encoding     => 'quoted-printable',
    },
  );

  my @dumps;
  for my $key (sort keys %$dumpable) {
    my $dump = Email::MIME->create(
      body_str   => Dump($dumpable->{$key}),
      attributes => {
        name         => $key,
        filename     => "$key.yaml",
        content_type => "text/plain", # could be better
        charset      => 'utf-8',
        encoding     => 'quoted-printable',
      },
    );

    push @dumps, $dump;
  }

  # XXX: move this up into the dumpables block -- rjbs, 2010-10-26
  # for my $attachment (@{ $arg->{attach_files} }) {
  #   my $attachment = Email::MIME->create(
  #     body       => scalar do {
  #       local $/;
  #       open my $fh, '<', $attachment->{filename};
  #       <$fh>;
  #     },
  #     attributes => {
  #       name         => $attachment->{description},
  #       filename     => $attachment->{filename},
  #       content_type => $attachment->{content_type} || 'application/unknown',
  #     },
  #   );
  #   push @dumps, $attachment;
  # }

  # XXX: If Email::MIME could do a plaintext prelude, we'd use that, I think.
  # Using this means the part 0 isn't always the exception.  That's OK.
  my @prelude;
  if ($summary->{handled}) {
    push @prelude, Email::MIME->create(
      body_str   => "DON'T PANIC!\n"
                  . "THIS EXCEPTION WAS CAUGHT AND EXECUTION CONTINUED\n"
                  . "THIS REPORT IS PROVIDED FOR INFORMATIONAL PURPOSES\n",
      attributes => {
        content_type => "text/plain", # could be better
        charset      => 'utf-8',
        encoding     => 'quoted-printable',
        name         => 'prelude',
        filename     => 'prelude.txt',
      },
    );
  }

  (my $digest_desc = $description) =~ s/\(.+//g;

  my ($package, $filename, $line) = caller;

  my $email = Email::MIME->create(
    attributes => { content_type => 'multipart/mixed' },
    parts      => [ @prelude, $summary, @dumps ],
    header     => [
      From => 'root',
      To   => 'IC Group Sysadmins <sysadmins@icgroup.com>',
      Date => format_date,
      Subject      => elide("$arg->{reporter}: $description", 65),
      'X-Mailer'   => __PACKAGE__,
      'Message-Id' => '<' . Email::MessageID->new(user => $guid) . '>',
      'In-Reply-To'=> '<' . Email::MessageID->new(
        user => md5_hex($digest_desc),
        host => $arg->{reporter},
      ) . '>',
      'X-Exception-Reporter-Reporter' => "$filename line $line ($package)",
      'X-Exception-Reporter-Handled'  => ($arg->{handled} ? 1 : 0),
    ],
  );

  eval {
    Email::Sender::Simple->sendmail(
      $email,
      {
        from    => 'root',
        to      => [
          'sysadmins@icgroup.com', @{ $arg->{extra_rcpts} || [] },
        ],
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

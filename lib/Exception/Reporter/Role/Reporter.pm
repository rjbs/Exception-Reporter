package Exception::Reporter::Role::Reporter;
use Moose::Role;
# ABSTRACT: a thing that can report exceptions

=head2 report_exception

  my $id = $reporter->report_exception($error, \%dumpable, \%arg);

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
  my ($self, $exception, $dumpable, $arg) = @_;
  $dumpable ||= {};
  $arg ||= {};

  $arg->{reporter} ||= $0;
  $arg->{attach_files} ||= [];

  require Data::GUID;
  require Digest::MD5;
  require Email::Date;
  require Email::MIME::Creator;
  require Email::MessageID;
  require Email::Sender::Simple;
  require String::Truncate;

  $dumpable->{env} ||= \%ENV;
  my $guid = Data::GUID->new->as_string;

  my $description;
  my $error_string;

  if (eval { $exception->isa('Exception::Class::Base') }) {
    $description = eval { $exception->description . ': ' . $exception->error };
    $description = "(no description)"
      unless defined $description and length $description;

    $error_string = eval { $exception->can('as_text') }
                  ? $exception->as_text # Mason exceptions "" to html otherwise
                  : $exception->as_string;
  } else {
    $error_string = $exception;
    $error_string =~ s/\A\s+//sm;
    my ($first_line)  = split /\n/, $error_string, 2;
    $first_line = "(no description)"
      unless defined $first_line and length $first_line;
    $first_line =~ s/\s+(?:at .+?)? ?line\s\d+\.?$//;
    $description = $first_line;
  }

  my $summary = Email::MIME->create(
    body       => $error_string,
    attributes => {
      content_type => "text/plain",
      filename     => 'exception.txt',
    },
  );

  my @dumps;
  for my $key (sort keys %$dumpable) {
    my $dump = Email::MIME->create(
      body       => YAML::Syck::Dump($dumpable->{$key}),
      attributes => {
        name         => $key,
        filename     => "$key.yaml",
        content_type => "text/plain", # could be better
      },
    );
    push @dumps, $dump;
  }

  for my $attachment (@{ $arg->{attach_files} }) {
    my $attachment = Email::MIME->create(
      body       => scalar do {
        local $/;
        open my $fh, '<', $attachment->{filename};
        <$fh>;
      },
      attributes => {
        name         => $attachment->{description},
        filename     => $attachment->{filename},
        content_type => $attachment->{content_type} || 'application/unknown',
      },
    );
    push @dumps, $attachment;
  }

  # XXX: If Email::MIME could do a plaintext prelude, we'd use that, I think.
  # Using this means the part 0 isn't always the exception.  That's OK.
  my @prelude;
  if ($arg->{handled}) {
    push @prelude, Email::MIME->create(
      body       => "DON'T PANIC!\n"
                  . "THIS EXCEPTION WAS CAUGHT AND EXECUTION CONTINUED\n"
                  . "THIS REPORT IS PROVIDED FOR INFORMATIONAL PURPOSES\n",
      attributes => {
        name         => 'prelude',
        filename     => 'prelude.txt',
        content_type => "text/plain", # could be better
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
      Date => Email::Date::format_date(),
      Subject      => String::Truncate::elide(
        "$arg->{reporter}: $description",
        65,
      ),
      'X-Mailer'   => __PACKAGE__,
      'Message-Id' => '<' . Email::MessageID->new(user => $guid) . '>',
      'In-Reply-To'=> '<' . Email::MessageID->new(
        user => Digest::MD5::md5_hex($digest_desc),
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

  return $guid;
}

1;

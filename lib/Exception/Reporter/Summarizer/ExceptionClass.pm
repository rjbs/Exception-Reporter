use strict;
use warnings;
package Exception::Reporter::Summarizer::ExceptionClass;
use parent 'Exception::Reporter::Summarizer';

=head1 OVERVIEW

This summarizer handles only L<Exception::Class> objects.  A dumped exception
will result in between one and four summaries:

  * a text summary of the exceptions full message
  * if available, a dump of the exception's pid, time, uid, etc.
  * if available, the stringification of the exception's stack trace
  * if any fields are defined, a dump of the exception's fields

=cut

use Exception::Class 1.30; # NoContextInfo
use Try::Tiny;

sub can_summarize {
  my ($self, $entry) = @_;
  return try { $entry->[1]->isa('Exception::Class::Base') };
}

sub summarize {
  my ($self, $entry, $internal_arg) = @_;
  my ($name, $exception, $arg) = @$entry;

  my $fn_base = $self->sanitize_filename($name);

  my $ident = $exception->error;
  ($ident) = split /\n/, $ident; # only the first line, please

  # Yes, I have seen the case below need handling! -- rjbs, 2012-07-03
  $ident = "exception of class " . ref $exception unless length $ident;

  # Another option here is to dump this in a few parts:
  # * a YAML dump of the message, error, and fields
  # * a dump of the stack trace
  my @summaries = ({
    filename => "exception-msg.txt",
    mimetype => 'text/plain',
    ident    => $ident,
    body     => $exception->full_message,
  });

  if (! $exception->NoContextInfo) {
    my $context = $internal_arg->{dumper}->dump({
      time => $exception->time,
      pid  => $exception->pid,
      uid  => $exception->uid,
      euid => $exception->euid,
      gid  => $exception->gid,
      egid => $exception->egid,
    });

    push @summaries, (
      {
        filename => "exception-stack.txt",
        mimetype => 'text/plain',
        ident    => "stack trace",
        body     => $exception->trace->as_string({
          max_arg_length => 0,
        }),
      },
      {
        filename => "exception-context.txt",
        mimetype => $context->{mimetype},
        ident    => "context info",
        body     => $context->{body},
      },
    );
  }

  if ($exception->Fields) {
    my $hash = {};
    for my $field ($exception->Fields) {
      $hash->{ $field } = $exception->$field;
    }

    my $fields = $internal_arg->{dumper}->dump($hash);
    push @summaries, {
      filename => "exception-context.txt",
      mimetype => $fields->{mimetype},
      ident    => "context info",
      body     => $fields->{body},
    };
  }

  return @summaries;
}

1;

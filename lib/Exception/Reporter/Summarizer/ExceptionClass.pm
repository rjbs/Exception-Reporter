use strict;
use warnings;
package Exception::Reporter::Summarizer::ExceptionClass;
use parent 'Exception::Reporter::Summarizer';

use YAML::XS ();
use Try::Tiny;

sub can_summarize {
  my ($self, $entry) = @_;
  return try { $entry->[1]->isa('Exception::Class::Base') };
}

sub summarize {
  my ($self, $entry) = @_;
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
    push @summaries, (
      {
        filename => "exception-stack.txt",
        mimetype => 'text/plain',
        ident    => "stack trace",
        body     => $exception->full_message,
      },
      {
        filename => "exception-context.txt",
        mimetype => 'text/plain',
        ident    => "context info",
        body     => YAML::XS::Dump({
          time => $exception->time,
          pid  => $exception->pid,
          uid  => $exception->uid,
          euid => $exception->euid,
          gid  => $exception->gid,
          egid => $exception->egid,
        }),
      },
    );
  }

  if ($exception->Fields) {
    my $hash = {};
    for my $field ($exception->Fields) {
      $hash->{ $field } = $exception->$field;
    }

    push @summaries, {
      filename => "exception-context.txt",
      mimetype => 'text/plain',
      ident    => "context info",
      body     => YAML::XS::Dump($hash),
    };
  }

  return @summaries;
}

1;

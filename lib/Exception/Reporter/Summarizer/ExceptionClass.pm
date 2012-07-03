use strict;
use warnings;
package Exception::Reporter::Summarizer::ExceptionClass;
use parent 'Exception::Reporter::Summarizer';

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

  # Another option here is to dump this in a few parts:
  # * a YAML dump of the message, error, and fields
  # * a dump of the stack trace
  return(
    {
      filename => "exception.txt",
      mimetype => 'text/plain',
      ident    => $ident,
      body     => join(qq{\n\n}, $exception->full_message,
                                 $exception->trace->as_string),
    }
  );
}

1;

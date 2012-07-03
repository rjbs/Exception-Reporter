use strict;
use warnings;
package Exception::Reporter::Summarizer::Email;
use parent 'Exception::Reporter::Summarizer';

use Try::Tiny;

sub can_summarize {
  my ($self, $entry) = @_;
  return try { $entry->[1]->isa('Email::Simple') };
}

sub summarize {
  my ($self, $entry) = @_;
  my ($name, $value, $arg) = @$entry;

  my $fn_base = $self->sanitize_filename($name);

  return {
    filename => "$fn_base.msg",
    mimetype => 'message/rfc822',
    ident    => "email message for $fn_base",
    body     => $value->as_string,
  };
}

1;

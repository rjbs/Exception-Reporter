use strict;
use warnings;
package Exception::Reporter::Summarizer::Email;
# ABSTRACT: a summarizer for Email::Simple objects

use parent 'Exception::Reporter::Summarizer';

=head1 OVERVIEW

This summarizer will only summarize Email::Simple (or subclass) objects.  The
emails will be summarized as C<message/rfc822> data containing the
stringification of the message.

=cut

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
    body_is_bytes => 1,
  };
}

1;

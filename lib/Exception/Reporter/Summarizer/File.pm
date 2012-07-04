use strict;
use warnings;
package Exception::Reporter::Summarizer::File;
use parent 'Exception::Reporter::Summarizer';

=head1 OVERVIEW

This summarizer expects L<Exception::Reporter::Dumpable::File> objects, and
summarizes them just as you might expect.

=cut

use File::Basename ();
use Try::Tiny;

sub can_summarize {
  my ($self, $entry) = @_;
  return try { $entry->[1]->isa('Exception::Reporter::Dumpable::File') };
}

sub summarize {
  my ($self, $entry) = @_;
  my ($name, $value, $arg) = @$entry;

  my $fn_base = $self->sanitize_filename(
    File::Basename::basename($value->path)
  );

  return {
    filename => $fn_base,
    mimetype => $value->mimetype,
    ident    => "file at $name",
    body     => ${ $value->contents_ref },
    body_is_bytes => 1,
    ($value->charset ? (charset => $value->charset) : ()),
  };
}

1;

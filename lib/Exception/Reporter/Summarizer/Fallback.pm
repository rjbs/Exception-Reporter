use strict;
use warnings;
package Exception::Reporter::Summarizer::Fallback;
# ABSTRACT: a summarizer for stuff you couldn't deal with otherwise

use parent 'Exception::Reporter::Summarizer';

=head1 OVERVIEW

This summarizer will accept any input and summarize it by dumping it with the
Exception::Reporter's dumper.

I recommended that this summarizer is always in your list of summarizers,
and always last.

=cut

use Try::Tiny;

sub can_summarize { 1 }

sub summarize {
  my ($self, $entry, $internal_arg) = @_;
  my ($name, $value, $arg) = @$entry;

  my $fn_base = $self->sanitize_filename($name);

  my $dump = $self->dump($value, { basename => $fn_base });

  return {
    filename => "$fn_base.txt",
    ident    => "dump of $name",
    %$dump,
  };
}

1;

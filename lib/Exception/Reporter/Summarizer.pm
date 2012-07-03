use strict;
use warnings;
package Exception::Reporter::Summarizer;

sub new {
  my ($class, $arg) = @_;

  return bless {}, $class;
}

sub sanitize_filename {
  my ($self, $filename) = @_;

  $filename =~ s/[^-a-zA-Z0-9]/-/g;
  return $filename;
}

1;

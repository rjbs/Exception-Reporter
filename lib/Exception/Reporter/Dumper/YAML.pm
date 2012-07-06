use strict;
use warnings;
package Exception::Reporter::Dumper::YAML;
use parent 'Exception::Reporter::Dumper';

use Try::Tiny;
use YAML ();

sub dump {
  my ($self, $value) = @_;

  my ($dump, $error) = try {
    (YAML::Dump($value), undef);
  } catch {
    (undef, $_);
  };

  if (defined $dump) {
    my $ident = $dump;
    $ident =~ s/\A---\s*//; # strip the document marker
    ($ident) = split /\n/, $ident;

    return {
      mimetype => 'text/plain',
      body     => $dump,
      ident    => $ident,
    };
  } else {
    my $string = try { "$value" } catch { "value could not stringify: $_" };
    return {
      mimetype => 'text/plain',
      body     => $string,
    };
  }
}

1;

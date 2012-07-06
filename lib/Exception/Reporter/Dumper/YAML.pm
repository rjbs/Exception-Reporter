use strict;
use warnings;
package Exception::Reporter::Dumper::YAML;
use parent 'Exception::Reporter::Dumper';

use Try::Tiny;
use YAML ();

sub dump {
  my ($self, $value, $arg) = @_;
  my $basename = $arg->{basename} || 'dump';

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
      extension => "$basename.yaml",
      mimetype  => 'text/plain',
      body      => $dump,
      ident     => $ident,
    };
  } else {
    my $string = try { "$value" } catch { "value could not stringify: $_" };
    return {
      extension => "$basename.txt",
      mimetype  => 'text/plain',
      body      => $string,
    };
  }
}

1;

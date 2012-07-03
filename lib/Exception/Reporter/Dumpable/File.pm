use strict;
use warnings;
package Exception::Reporter::Dumpable::File;

#    filename => ..., # from base above
#    mimetype => ..., # from file object
#    ident    => "file " . ..., # actual filename
#    body     => ..., # from file object
#    body_is_bytes => ..., # from file object

sub _err_msg {
  my ($class, $path, $msg) = @_;
  return "(file at <$path> was requested for dumping, but $msg)";
}

sub new {
  my ($class, $path, $arg) = @_;
  $arg ||= {};

  return $class->_err_msg($path, 'does not exist') unless -e $path;

  my $realpath = -l $path ? readlink $path : $path;

  return $class->_err_msg($path, 'is not a normal file') unless -f $realpath;

  return $class->_err_msg($path, "can't be read") unless -r $realpath;

  if ($arg->{max_size}) {
    my $size = -s $realpath;
    if ($size > $arg->{max_size}) {
      return $class->_err_msg(
        $path,
        "its size $size " . "exceeds maximum allowed size $arg->{max_size}"
      );
    }
  }

  my $guts = { path => $path };

  $guts->{mimetype} = $arg->{mimetype}
                   || $class->_mimetype_from_filename($path)
                   || 'application/octet-stream';

  $guts->{charset} = $arg->{charset}
                  || $guts->{mimetype} =~ m{\Atext/} ? 'utf-8' : undef;

  open my $fh, '<', $path
    or return $class->_err_msg("there was an error reading it: $!");

  my $contents = do { local $/; <$fh> };

  $guts->{contents_ref} = \$contents;

  bless $guts => $class;
}

sub path     { $_[0]->{path} }
sub mimetype { $_[0]->{mimetype} }
sub charset  { $_[0]->{charset} }
sub contents_ref { $_[0]->{contents_ref} }

# replace with MIME::Type or something -- rjbs, 2012-07-03
my %LOOKUP = (
  txt  => 'text/plain',
  html => 'text/html',
);

sub _mimetype_from_filename {
  my ($class, $filename) = @_;

  my ($extension) = $filename =~ m{\.(.+?)\z};
  return unless $extension;

  return $LOOKUP{ $extension };
}

1;

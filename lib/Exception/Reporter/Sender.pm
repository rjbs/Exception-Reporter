use strict;
use warnings;
package Exception::Reporter::Sender;
# ABSTRACT: a thing that sends exception reports

=head1 OVERVIEW

This class exists almost entirely to allow C<isa>-checking.  It provides a
C<new> method that returns a blessed, empty object.  Passing it any parameters
will cause an exception to be thrown.

=cut

1;

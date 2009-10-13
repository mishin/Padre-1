#
# This class is indented to be automatically loaded by Padre::DB,
# overlaying the code already auto-generated by Padre::DB.
#

package Padre::DB::LastPositionInFile;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.48';

sub get_last_pos {
	my ( $class, $name ) = @_;
	my $recent = Padre::DB->selectcol_arrayref(
		"select position from last_position_in_file where name = ?",
		{}, $name,
	);
	return $recent->[0];
}

sub set_last_pos {
	my ( $class, $name, $pos ) = @_;

	$class->delete( 'where name = ?', $name );
	$class->create(
		name     => $name,
		position => $pos,
	);
}

1;

__END__

=pod

=head1 NAME

Padre::DB::LastPositionInFile - db table keeping last position in a file


=head1 SYNOPSIS

        Padre::DB::LastPositionInFile->set_last_pos($file, $pos);
        my $pos = Padre::DB::LastPositionInFile->get_last_pos($file);



=head1 DESCRIPTION

This class allows storing in Padre's database the last cursor position
in a file. This is useful in order to put the cursor back to where it
was when re-opening this file later on.



=head1 PUBLIC METHODS

=head2 Accessors

The following accessors are automatically created by C<ORLite>:

=over 4

=item name()

=item position()

=back


=head2 Class methods

The following subs are automatically created by C<ORLite>. Refer to C<ORLite>
for more information on them:

=over 4

=item select()

=item count()

=item new()

=item create()

=item insert()

=item delete()

=item truncate()

=back



=head2 set_large_pos( $file, $pos )

Record C<$pos> as the last known cursor position in C<$file>.


=head2 get_large_pos( $file )

Return the last known cursor position for C<$file>. Return undef if
no position was recorded for this file.



=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 The Padre development team as listed in Padre.pm.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

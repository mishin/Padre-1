package Padre::Locker;

=pod

=head1 NAME

Padre::Locker - The Padre Multi-Resource Lock Manager

=cut

use 5.008;
use strict;
use warnings;
use Padre::Lock ();
use Padre::DB   ();

our $VERSION = '0.53';

sub new {
	my $class = shift;
	my $owner = shift;

	# Create the object
	my $self = bless {
		owner => $owner,

		# Padre::DB Transaction lock
		db_depth => 0,

		# Wx ->Update lock
		update_depth  => 0,
		update_locker => undef,

		# Wx "Busy" lock
		busy_depth  => 0,
		busy_locker => undef,

		# Padre ->refresh lock
		method_depth   => 0,
		method_pending => {},
	}, $class;
}

sub lock {
	Padre::Lock->new( shift, @_ );
}

sub locked {
	my $self  = shift;
	my $asset = shift;
	if ( $asset eq 'UPDATE' ) {
		return !!$self->{update_depth};
	} elsif ( $asset eq 'BUSY' ) {
		return !!$self->{busy_depth};
	} elsif ( $asset eq 'REFRESH' ) {
		return !!$self->{method_depth};
	} else {
		return !!$self->{method_pending}->{$asset};
	}
}

# During Padre shutdown we should disable all forms of screen updating,
# once we have completed all user-interactive steps in the shutdown.
# Calling the shutdown method will apply the UPDATE lock to prevent any
# further screen painting, and then permanently ignore any and all attempts
# to call refresh methods.
# This method does NOT ->Hide the actual application, that is left up to the
# shutdown process. This action just disables everything lock-related that
# might slow the shutdown process.
sub shutdown {
	my $self = shift;
	my $lock = $self->lock( 'UPDATE', 'REFRESH' );
	$self->{shutdown} = 1;
	return 1;
}





######################################################################
# Locking Mechanism

# Database locking like this is only possible because Padre NEVER makes
# use of rollback. All bad database requests are considered fatal.

sub db_increment {
	my $self = shift;
	unless ( $self->{db_depth}++ ) {
		Padre::DB->begin;
	}
	return;
}

sub db_decrement {
	my $self = shift;
	unless ( --$self->{db_depth} ) {
		Padre::DB->commit;
	}
	return;
}

sub update_increment {
	my $self = shift;
	unless ( $self->{update_depth}++ ) {

		# Locking for the first time
		$self->{update_locker} = Wx::WindowUpdateLocker->new( $self->{owner} );
	}
	return;
}

sub update_decrement {
	my $self = shift;
	unless ( --$self->{update_depth} ) {

		# Unlocked for the final time
		unless ( $self->{shutdown} ) {
			$self->{update_locker} = undef;
		}
	}
	return;
}

sub busy_increment {
	my $self = shift;
	unless ( $self->{busy_depth}++ ) {

		# Locking for the first time
		# If we are in shutdown, the application isn't painting anyway
		# (or possibly even visible) so don't put us into busy state.
		unless ( $self->{shutdown} ) {
			$self->{busy_locker} = Wx::BusyCursor->new;
		}
	}
	return;
}

sub busy_decrement {
	my $self = shift;
	unless ( --$self->{busy_depth} ) {

		# Unlocked for the final time
		unless ( $self->{shutdown} ) {
			$self->{busy_locker} = undef;
		}
	}
	return;
}

sub method_increment {
	$_[0]->{method_depth}++;
	$_[0]->{method_pending}->{ $_[1] }++;
	return;
}

sub method_decrement {
	my $self = shift;
	$self->{method_pending}->{ $_[0] }--;
	unless ( --$self->{method_depth} ) {

		# Once we start the shutdown process, don't run anything
		return if $self->{shutdown};

		# Run all of the pending methods
		foreach ( keys %{ $self->{method_pending} } ) {
			next if $_ eq uc($_);
			$self->{owner}->$_();
		}
		$self->{method_pending} = {};
	}
	return;
}

1;

# Copyright 2008-2009 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
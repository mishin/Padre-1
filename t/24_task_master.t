#!/usr/bin/perl

# Start a worker thread from inside another thread

#BEGIN {
#$Padre::TaskThread::DEBUG = 1;
#$Padre::TaskWorker::DEBUG = 1;
#}

use strict;
use warnings;
use Test::More tests => 5;
use Test::NoWarnings;
use Time::HiRes 'sleep';
use Padre::Logger;
use Padre::TaskThread ':master';

# Do we start with one thread as expected
sleep 0.1;
is( scalar( threads->list ), 1, 'One thread exists' );

# Fetch the master, is it the existing one?
my $master1 = Padre::TaskThread->master;
my $master2 = Padre::TaskThread->master;
isa_ok( $master1, 'Padre::TaskThread' );
isa_ok( $master2, 'Padre::TaskThread' );
is( $master1->wid, $master2->wid, 'Masters match' );
use strict;
use warnings;
use Test::More;
use Test::Refcount;
use Test::Fatal;
use Test::Future;

use Future::Utils;
use IO::Async::Loop;
use Net::Async::AMQP::ConnectionManager;

plan skip_all => 'set NET_ASYNC_AMQP_HOST/USER/PASS/VHOST env vars to test' unless exists $ENV{NET_ASYNC_AMQP_HOST};

my $loop = IO::Async::Loop->new;

# Set up a connection manager with our MQ server details
$loop->add(
	my $cm = Net::Async::AMQP::ConnectionManager->new
);
$cm->add(
	host  => $ENV{NET_ASYNC_AMQP_HOST},
	user  => $ENV{NET_ASYNC_AMQP_USER},
	pass  => $ENV{NET_ASYNC_AMQP_PASS},
	vhost => $ENV{NET_ASYNC_AMQP_VHOST},
	max_channels => 16,
);

my @seen;
(Future::Utils::fmap_void {
	my $wch;
	$cm->request_channel->then(sub {
		my $ch = shift;
		Scalar::Util::weaken($wch = $ch);
		ok($ch->id, 'have a channel');
		is($cm->connection_count, 1, 'only using a single connection');
		$ch->exchange_declare(
			exchange => 'test_exchange',
			type     => 'fanout',
		)
	})->on_done(sub {
		is($wch, undef, 'channel proxy has disappeared');
		pass('succeeded')
	})->on_fail(sub {
		fail('invalid')
	})->on_cancel(sub {
		fail('cancelled')
	});
} foreach => [1..8], concurrent => 4)->get;

$cm->request_channel->then(sub {
	my $ch = shift;
	like(exception {
		$ch->confirm_mode->get
	}, qr/Cannot apply confirm mode/, 'cannot apply confirm_mode on a managed channel');
	Future->wrap;
})->get;

{
	my @ch;
	is($cm->connection_count, 1, 'start with a single connection');
	for(1..16) {
		push @ch, $cm->request_channel->get;
	}
	is($cm->connection_count, 1, 'still only a single connection') or <>;
	is(exception {
		push @ch, $cm->request_channel->get;
	}, undef, 'can still assign channels after hitting limit'); 
	is($cm->connection_count, 2, 'now have two connections');
	for(1..16) {
		push @ch, $cm->request_channel->get;
	}
	is($cm->connection_count, 3, 'assign more channels, now have three connections');
	@ch = ();
	is($cm->connection_count, 3, 'still 3 connections after releasing all channels');
	for(1..16) {
		push @ch, $cm->request_channel->get;
	}
	is($cm->connection_count, 3, 'still 3 connections after assigning a full connection');
}

$cm->shutdown->get;

done_testing;


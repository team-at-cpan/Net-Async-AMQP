package Net::Async::AMQP::RPC::Server;

use strict;
use warnings;

use parent qw(Net::Async::AMQP::RPC::Base);

=head1 NAME

Net::Async::AMQP::RPC::Server - server RPC handling

=head1 DESCRIPTION

Provides a server implementation for RPC handling.

=over 4

=item * Declare a queue

=item * Declare the RPC exchange

=item * Bind our queue to the exchange

=item * Start a consumer on the queue

=item * For each message, process via subclass-defined handlers and send a reply to the default ('') exchange with the reply_to as the routing key

=back

=cut

use Variable::Disposition qw(retain_future);

use Log::Any qw($log);

sub queue { shift->server_queue }

sub json {
	shift->{json} //= do {
		eval {
			require JSON::MaybeXS;
		} or die "JSON RPC support requires the JSON::MaybeXS module, which could not be loaded:\n$@";
		JSON::MaybeXS->new
	}
}

sub process_message {
	my ($self, %args) = @_;
	$log->infof("Have message: %s", join ' ', %args);
	$self->reply(
		reply_to => $args{reply_to},
		correlation_id => $args{id},
		type => $args{type},
		payload => '{ "status": "ok" }',
	);
}

sub configure {
	my ($self, %args) = @_;
	for (qw(json_handler handler)) {
		$self->{$_} = delete $args{$_} if exists $args{$_}
	}
	$self->SUPER::configure(%args)
}

1;

__END__

=head1 AUTHOR

Tom Molesworth <TEAM@cpan.org>

=head1 LICENSE

Licensed under the same terms as Perl itself, with additional licensing
terms for the MQ spec to be found in C<share/amqp0-9-1.extended.xml>
('a worldwide, perpetual, royalty-free, nontransferable, nonexclusive
license to (i) copy, display, distribute and implement the Advanced
Messaging Queue Protocol ("AMQP") Specification').


#!/usr/bin/perl

## simple udp|tcp client|server
## Roman E. Chechnev
## https://github.com/m0r1k

use strict;
use warnings;
use IO::Socket::INET;

use constant VERSION => 20241202124027;

sub udp_client()
{
    my $host         = $ARGV[1];
    my $port         = $ARGV[2];
    my $payload_size = $ARGV[3];
    my $ret          = -1;

    unless (defined $host) {
        print("missing argument: 'host'\n");
        goto fail;
    }

    unless (defined $port) {
        print("missing argument: 'port'\n");
        goto fail;
    }

    unless (defined $payload_size) {
        print("missing argument: 'payload_size'\n");
        goto fail;
    }

    my ($datagram, $flags);

    my @symbols = (("0".."9"),("a".."z"),("A".."Z"));
    my $symbols_len = scalar(@symbols);

    my $data = '';
    my $pos  = 0;
    for (my $i = 0 ; $i < $payload_size; $i++) {
        $data .= $symbols[$pos];
        $pos++;
        if ($symbols_len <= $pos) {
            $pos = 0;
        }
    }

    my $sock = IO::Socket::INET->new(
        PeerHost => $host,
        PeerPort => $port,
        Proto    => 'udp'
    );

    my $res = $sock->send($data)
        or die("cannot send to socket ($!)");

    print("sent $res/$payload_size byte(s)\n");
    print("wait answer\n");

    $sock->recv($datagram, length($data), $flags);

    print "got: " . length($datagram) . " byte(s)\n";

    ## all ok
    $ret = 0;

out:
    return $ret;
fail:
    $ret = -1;
    goto out;
}

sub udp_server()
{
    my $host = $ARGV[1];
    my $port = $ARGV[2];
    my $ret  = -1;

    if (!$host) {
        print("missing argument: 'host'\n");
        goto fail;
    }

    if (!$port) {
        print("missing argument: 'port'\n");
        goto fail;
    }


    my $max_len = 65535;
    my $sock    = IO::Socket::INET->new(
        LocalAddr => $host,
        LocalPort => $port,
        Proto     => 'udp'
    );

    print "listen on $host:$port\n";

    my $new_msg = undef;

    while ($sock->recv($new_msg, $max_len)) {
        my ($port, $ipaddr) = sockaddr_in($sock->peername);
        my $peer_addr       = inet_ntoa($ipaddr);
        my $new_msg_len     = length($new_msg);
        print("got from: '$peer_addr:$port'"
            ." $new_msg_len byte(s), send back\n"
        );
        ## send back
        my $res = $sock->send($new_msg)
            or die("cannot send to socket ($!)\n");
        print("sent to '$peer_addr:$port' $res byte(s)\n");
    }

    ## all ok
    $ret = 0;

out:
    return $ret;
fail:
    $ret = -1;
    goto out;
}

sub tcp_client()
{
    my $host         = $ARGV[1];
    my $port         = $ARGV[2];
    my $payload_size = $ARGV[3];
    my $ret          = -1;

    unless (defined $host) {
        print("missing argument: 'host'\n");
        goto fail;
    }

    unless (defined $port) {
        print("missing argument: 'port'\n");
        goto fail;
    }

    unless (defined $payload_size) {
        print("missing argument: 'payload_size'\n");
        goto fail;
    }

    my ($answer, $answer_len, $flags);

    my @symbols = (("0".."9"),("a".."z"),("A".."Z"));
    my $symbols_len = scalar(@symbols);

    my $data = '';
    my $pos  = 0;
    for (my $i = 0 ; $i < $payload_size; $i++) {
        $data .= $symbols[$pos];
        $pos++;
        if ($symbols_len <= $pos) {
            $pos = 0;
        }
    }

    my $sock = IO::Socket::INET->new(
        PeerHost => $host,
        PeerPort => $port,
        Proto    => 'tcp'
    );

    unless ($sock) {
        print("cannot connect to '$host':'$port'\n");
        goto fail;
    }

    print("connected to '$host':'$port'\n");
    print("attempt to send $payload_size byte(s)\n");

    my $res = $sock->send($data)
        or die("cannot send to socket ($!)\n");

    print("send $res byte(s)\n");

    $answer_len = 0;
    while ($answer_len < $payload_size) {
        print("wait data\n");
        my ($buff, $buff_len);
	    $sock->sysread($buff, length($data))
            or die("cannot read from socket ($!)\n");
        $buff_len = length($buff);
        if (0 == $buff_len) {
            last;
        } elsif (0 > $buff_len) {
            print("cannot read from socket\n");
            last;
        }
        $answer     .= $buff;
        $answer_len += $buff_len;
	    print("got: $buff_len byte(s),"
            . " total got: $answer_len/$payload_size byte(s)"
            . "\n"
        );
    }

    print("total got: $answer_len/$payload_size byte(s)\n");

    $sock->close();

    ## all ok
    $ret = 0;

out:
    if ($sock) {
        $sock->close();
    }
    return $ret;
fail:
    $ret = -1;
    goto out;
}

sub tcp_server()
{
    my $host = $ARGV[1];
    my $port = $ARGV[2];
    my $ret  = -1;

    if (!$host) {
        print("missing argument: 'host'\n");
        goto fail;
    }

    if (!$port) {
        print("missing argument: 'port'\n");
        goto fail;
    }

    my $sock = IO::Socket::INET->new(
        LocalAddr => $host,
        LocalPort => $port,
        Proto     => 'tcp',
        Listen    => 5,
        Reuse     => 1
    );

    unless ($sock) {
        print "failed bind socket on $host:$port\n";
        goto fail;
    }

    print("listen on $host:$port\n");

    while(1) {
        my $client_socket = $sock->accept();
        unless ($client_socket) {
            print("failed accept on $host:$port\n");
            goto fail;
        }

        $client_socket->autoflush(1);

        my $client_address = $client_socket->peerhost();
        my $client_port    = $client_socket->peerport();
        my $written_total  = 0;

        print("client accepted: $client_address:$client_port\n");

        while (1) {
            my $new_msg;
            my $max_len  = 65535;
            my $was_read = $client_socket->sysread($new_msg, $max_len);
            unless($was_read) {
                print("client has closed connnection\n");
                last;
            }
            print("got $was_read byte(s)\n");
            ## send back
            my $written = $client_socket->send($new_msg)
                or die("cannot send to socket ($!)\n");

            $written_total += $written;
            print("$written byte(s) sent to socket ($written_total total)\n");
        }
        $client_socket->close();
    }

    ## all ok
    $ret = 0;

out:
    if ($sock) {
        $sock->close();
    }
    return $ret;
fail:
    $ret = -1;
    goto out;
}

sub usage()
{
    my @parts     = split(/\//, $0);
    my $self_name = pop(@parts);
    print("Usage $self_name <cmd> args..\n");
    print("cmd:\n");
    print("  udp_server <host> <port>\n");
    print("  udp_client <host> <port> <payload_size>\n");
    print("  tcp_server <host> <port>\n");
    print("  tcp_client <host> <port> <payload_size>\n");
}

my $type     = $ARGV[0] || '';
my $handlers = {
    "udp_server" => \&udp_server,
    "udp_client" => \&udp_client,
    "tcp_server" => \&tcp_server,
    "tcp_client" => \&tcp_client
};
my $ret;

my $handler = $handlers->{$type};
if ($handler) {
    $ret = $handler->();
} else {
    print("unknown type: '$type'\n");
    usage();
    $ret = -1;
}

exit($ret);


use v6.c;
unit module Net::NNG:ver<0.0.1>;
use NativeCall;

use Net::NNG::Options;

=begin pod

=head1 NAME

Net::NNG - NanoMSG networking with libnng

=head1 SYNOPSIS

    use Net::NNG;

    my $url = "tcp://127.0.0.1:8887";

    my $pub = nng-pub0-open;
    nng-listen $pub, $url;

    my @clients = do for 1..8 {
        start {
            CATCH { warn "Error in client $_: { .gist }" }

            my $sub nng-sub0-open;
            nng-dial = $sub, $url;
            for 1..15 -> $client-id {
                nng-subscribe $sub, "/count";

                say "Client $client-id: ", nng-recv($sub).tail.decode('utf8')
            }
            nng-close $sub
        }
    }

    my $server = start {
        CATCH { warn "Error in server: { .gist }" }

        for 1..15 {
            nng-send $pub, "/count$_".encode('utf8');
            sleep 0.5;
        }
    }

    await Promise.allof: |@clients, $server;

    nng-close $pub

=head1 DESCRIPTION

Net::NNG is a NativeCall binding for L<libnng|https://github.com/nanomsg/nng> a lightweight implementation of the nanomsg distributed messaging protocol.

This is currently an early release and isn't yet feature complete but provides usable subscribe/publish and request/reply patterns.
Other patterns currently offered by libnng such as survey and bus patterns are yet to be included in this interface.

This module does not yet handle providing you with a libnng library on your system so you will need to either build or install the library yourself.

=head1 AUTHOR

Sam Gillespie <samgwise@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Sam Gillespie

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# // Flags.
# enum nng_flag_enum {
#    NNG_FLAG_ALLOC    = 1, // Recv to allocate receive buffer.
#     NNG_FLAG_NONBLOCK = 2  // Non-blocking operations.
# };
our enum NNGFlag (
    NNG_FLAG_ALLOC => 1,
    NNG_FLAG_NONBLOCK => 2
);

# typedef struct nng_ctx_s {
#     uint32_t id;
# } nng_ctx;
#
# typedef struct nng_dialer_s {
#     uint32_t id;
# } nng_dialer;
class NNGDialer is repr<CStruct> {
    has uint32 $.id;
}

# typedef struct nng_listener_s {
#     uint32_t id;
# } nng_listener;
class NNGListener is repr<CStruct> {
    has uint32 $.id;
}

# typedef struct nng_pipe_s {
#     uint32_t id;
# } nng_pipe;
#
# typedef struct nng_socket_s {
#     uint32_t id;
# } nng_socket;

class NNGSocket is repr<CStruct> {
    has uint32 $.id;
}

# const char * nng_strerror(int err);
sub nng_strerror(int32) returns Str is encoded<utf8> is native<nng> { * }

# int nng_close(nng_socket s);
sub nng_close(int32) returns int64 is native { * }

sub nng-close(NNGSocket $socket --> Bool) is export {
    given nng_close($socket.id) {
        when 0 { True }
        default { fail "Failed to close socket: { .&nng_strerror }" }
    }
}

# void nng_free(void *ptr, size_t size);
sub nng_free(Pointer, uint64) is native<nng> { * }

# void *nng_alloc(size_t size);
sub nng_alloc(uint64) returns Pointer[void] is native<nng> { * }

#
# Socket options
#

# int nng_setopt(nng_socket s, const char *opt, const void *val, size_t valsz);
sub nng_setopt(int32, Str, Pointer, uint64) returns int64 is native<nng> { * }

#int nng_setopt_bool(nng_socket s, const char *opt, int bval);
sub nng_setopt_bool(int32, Str, uint8) returns int64 is native<nng> { * }

# int nng_setopt_int(nng_socket s, const char *opt, int ival);
sub nng_setopt_int(int32, Str, int64) returns int64 is native<nng> { * }

# int nng_setopt_ms(nng_socket s, const char *opt, nng_duration dur);
sub nng_setopt_ms(int32, Str, int32) returns int64 is native<nng> { * }

# int nng_setopt_ptr(nng_socket s, const char *opt, void *ptr);

# int nng_setopt_size(nng_socket s, const char *opt, size_t z);

# int nng_setopt_string(nng_socket s, const char *opt, const char *str);

# int nng_setopt_uint64(nng_socket s, const char *opt, uint64_t u64);
sub nng_setopt_uint64(int32, Str, uint64) returns int64 is native<nng> { * }

sub set-opt-check-error(int64 $error-code --> Bool) {

}

# Set an NNG::Option for a socket
multi sub nng-setopt(NNGSocket $socket, Str $name, Str $value) is export {
    my $packed-value = $value.encode('utf8');

    given nng_setopt($socket.id, $name, nativecast(Pointer[void], $packed-value), $packed-value.elems) {
        when 0 { True }
        default { fail "Unable to set option $name to $value ({ .&nng_strerror })" }
    }
}

multi sub nng-setopt(NNGSocket $socket, Str $name, Bool $value) is export {
    given nng_setopt_bool($socket.id, $name, $value) {
        when 0 { True }
        default { fail "Unable to set option $name to $value ({ .&nng_strerror })" }
    }
}

multi sub nng-setopt(NNGSocket $socket, Str $name, Int $value, Bool :$ms = False) is export {
    given $ms ?? nng_setopt_ms($socket.id, $name, $value) !! nng_setopt_int($socket.id, $name, $value) {
        when 0 { True }
        default { fail "Unable to set option $name to $value ({ .&nng_strerror })" }
    }
}

# Constants from src/protocol/pubsub0/sub.h
constant NNG_OPT_SUB_SUBSCRIBE = "sub:subscribe";
constant NNG_OPT_SUB_UNSUBSCRIBE = "sub:unsubscribe";

# Set an active subscription on a socket
sub nng-subscribe(NNGSocket $socket, Str $header) is export {
    my $value = $header.encode('utf8');
    given nng_setopt($socket.id, NNG_OPT_SUB_SUBSCRIBE, nativecast(Pointer[void], $value), $value.elems) {
        when 0 { True }
        default { fail "Unable to subscribe to $value ({ .&nng_strerror })" }
    }
}

# int nng_req0_open(nng_socket *s);
# return a pointer to ry and match the system int size
sub nng_req0_open(NNGSocket is rw) returns int64 is native<nng> { * }
sub nng_rep0_open(NNGSocket is rw) returns int64 is native<nng> { * }

our sub nng-req0-open( --> NNGSocket) is export {
    my $socket = NNGSocket.new(id => 0);
    given nng_req0_open($socket) {
        when 0 { $socket }
        default {
            fail "Failed creating v0 req socket: { .&nng_strerror }"
        }
    }
}

our sub nng-rep0-open( --> NNGSocket) is export {
    my $socket = NNGSocket.new(id => 0);
    given nng_rep0_open($socket) {
        when 0 { $socket }
        default {
            fail "Failed creating v0 rep socket:{ .&nng_strerror}"
        }
    }
}

# int nng_pub0_open(nng_socket *s);
sub nng_pub0_open(NNGSocket is rw) returns uint64 is native<nng> { * }

sub nng-pub0-open( --> NNGSocket) is export {
    my $socket = NNGSocket.new(id => 0);
    given nng_pub0_open($socket) {
        when 0 { $socket }
        default { fail "Failed creating v0 pub socket: { .&nng_strerror }" }
    }
}

# int nng_sub0_open(nng_socket *s);
sub nng_sub0_open(NNGSocket is rw) returns uint64 is native<nng> { * }

sub nng-sub0-open( --> NNGSocket) is export {
    my $socket = NNGSocket.new(id => 0);
    given nng_sub0_open($socket) {
        when 0 { $socket }
        default { fail "Failed creating v0 sub socket: { .&nng_strerror }" }
    }
}

# int nng_listen(nng_socket, const char *, nng_listener *, int);
sub nng_listen(int32, Str is encoded<utf8>, NNGListener is rw, int64) returns int64 is native<nng> { * }

# Start listening on a socket.
# returns True or Failure
our sub nng-listen(NNGSocket $socket, Str $url --> Bool) is export {
    given nng_listen($socket.id, $url, void, 0) {
        when 0 { True }
        default { fail "Failed creating listener on socket for url: $url ({ .&nng_strerror })"}
    }
}

# int nng_dial(nng_socket s, const char *url, nng_dialer *dp, int flags);
sub nng_dial(int32, Str is encoded<utf8>, NNGDialer is rw, int64) returns int64 is native<nng> { * }

sub nng-dial(NNGSocket $socket, Str $url --> Bool) is export {
    given nng_dial($socket.id, $url, void, 0) {
        when 0 { True }
        default { fail "Failed dialing on socket for url: $url ({ .&nng_strerror })" }
    }
}

#! a memcpy call for nng_recv, enabling us to copy the bytes from nng to a pre-allocated Blob
sub memcpy_recv(Pointer $dest, Pointer $src, size_t $size --> Pointer) is native is symbol('memcpy') { * }

# int nng_recv(nng_socket s, void *, size_t *, int);
sub nng_recv(int32 $s, Pointer $data is rw, uint64 $size is rw, int64 $flasgs) returns int64 is native<nng> { * }

#! Receives messages on a listener socket.
sub nng-recv(NNGSocket:D $socket --> Blob) is export {
    given nng_recv($socket.id, my Pointer[Pointer] $data .= new, my uint64 $body-size, NNG_FLAG_ALLOC) {
        when 0 {
            #my $body = nativecast(CArray[byte], $data.deref);
            #my $buffer = Blob.new: do for 0..^$body-size { $body.AT-POS($_) };
            my Blob $buffer .= allocate($body-size);
            memcpy_recv(nativecast(Pointer, $buffer), $data.deref, $body-size);
            nng_free($data.deref, $body-size);
            $buffer
        }
        default { fail "Failed receiving on socket: { .&nng_strerror }" }
    }
}

# int nng_send(nng_socket s, void *data, size_t size, int flags);
sub nng_send(int32, CArray[byte] is rw, uint64, int64) returns int64 is native<nng> { * }

sub nng-send(NNGSocket:D $socket, Blob $message --> Bool) is export {
    my uint64 $size = $message.elems;
    given nng_send($socket.id, nativecast(CArray[byte], $message), $size, 0) {
        when 0 { True }
        default {
            fail "Failed sending message: { .&nng_strerror }"
        }
    }
}

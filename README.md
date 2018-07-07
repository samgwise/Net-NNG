NAME
====

Net::NNG - NanoMSG networking with libnng

SYNOPSIS
========

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

DESCRIPTION
===========

Net::NNG is a NativeCall binding for [libnng](https://github.com/nanomsg/nng) a lightweight implementation of the nanomsg distributed messaging protocol.

This is currently an early release and isn't yet feature complete but provides usable subscribe/publish and request/reply patterns. Other patterns currently offered by libnng such as survey and bus patterns are yet to be included in this interface.

This module does not yet handle providing you with a libnng library on your system so you will need to either build or install the library yourself.

AUTHOR
======

Sam Gillespie <samgwise@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2018 Sam Gillespie

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.


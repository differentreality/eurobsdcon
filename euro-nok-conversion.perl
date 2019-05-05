#!/usr/bin/perl -Tw
#-
# Copyright (c) 2019 Dag-Erling Smørgrav
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

use utf8;
use strict;
use warnings;
use open qw(:locale);
use HTTP::Request;
use LWP::UserAgent;
use Try::Tiny;
use XML::DOM;
use XML::DOM::XPath;

# TODO: parametrize currency and # of observations
my $URLF = "https://data.norges-bank.no/api/data/EXR/B.%s.NOK.SP?lastNObservations=%d";

MAIN:{
    my $ua = new LWP::UserAgent;
    $ua->env_proxy;
    my $req = new HTTP::Request(GET => sprintf($URLF, 'EUR', 10));
    my $res = $ua->request($req)
    or die("Unknown LWP error\n");
    $res->is_success
    or die("LWP error: " . $res->status_line . "\n");
    my $xmlp = new XML::DOM::Parser;
    my $doc = (try { $xmlp->parse($res->decoded_content); })
        or die("XML error: $_\n");
    print("period,base,quote,rate\n");
    foreach my $series ($doc->findnodes('//Series')) {
    my $base = $series->getAttribute('BASE_CUR');
    $base =~ s/^([A-Z]{3})$/$1/r
        or die("Invalid base currency\n");
    my $quote = $series->getAttribute('QUOTE_CUR');
    $quote =~ s/^([A-Z]{3})$/$1/r
        or die("Invalid quote currency\n");
    foreach my $obs ($series->findnodes('Obs')) {
        my $period = $obs->getAttribute('TIME_PERIOD');
        $period =~ s/^(\d\d\d\d-\d\d-\d\d)$/$1/r
        or die("Invalid time period\n");
        my $rate = $obs->getAttribute('OBS_VALUE');
        $rate =~ s/^(\d+\.\d+)$/$1/r
        or die("Invalid exchange rate\n");
        print("$period,$base,$quote,$rate\n");
    }
    }
    $doc->dispose;
}

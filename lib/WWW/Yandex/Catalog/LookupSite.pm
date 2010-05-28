package WWW::Yandex::Catalog::LookupSite;

# Last updated May 27, 2010
#
# Author:       Irakliy Sunguryan ( www.sochi-travel.info )
# Date Created: January 30, 2010

use strict;
#use warnings;

use vars qw($VERSION);
$VERSION    = '0.06';

use LWP::Simple;

sub new {
    my $class = shift;
    my $self = {
        _tic        => undef,
            # undef - if there was an error getting or parsing data
            # 0     - (a) when site is not present in catalog and tIC is < 10
            #       - (b) when site is present in catalog, but the catalog 
            #             reports it as zero (payed submission)
        _shortDescr => undef,
            # defined only when site is present in catalog; undef otherwise
        _longDescr  => undef,
            # can be undef when site is present in catalog!
            # not all sites in the catalog have long description
        _categories => []
            # empty when site is not present in catalog
            # at least one entry when present in catalog
    };
    bless $self, $class;
    return $self;
}


# returns [ tIC, short description, long description, [catalogs] ]
# "yaca" - Yandex Catalog
sub yaca_lookup {
    my $self = shift;
    my $address = shift || return;

    # an $address is nomally a domain name (whatever level), but can include path too.
    # scheme, authentication, port, and query strings are stripped --
    #   assuming Yandex won't accept URIs that contain all this

    $self->{_tic} = $self->{_shortDescr} = $self->{_longDescr} = undef;
    $self->{_categories} = [];

    $address =~ s|.*?://||;       # loose scheme
    $address =~ s|.*?(:.*?)?@||;  # loose authentication
    $address =~ s|(\w):\d+|$1|;   # loose port
    $address =~ s|\?.*||;         # loose query
    $address =~ s|/$||;           # loose trailing slash

    my $contents = get( 'http://search.yaca.yandex.ru/yca/cy/ch/' . $address );

    return unless defined $contents;

    if( $contents =~ /<p class="errmsg">/ ) {
        # It's not in the catalog, but tIC is displayed or reported as < 10:
        #   Индекс цитирования (тИЦ) ресурса меньше 10.         (under 10)
        #   Индекс цитирования (тИЦ) ресурса — 10               (equals to 10)
        ( $self->{_tic} ) = $contents =~ /<p class="errmsg">.*?<b>.*?(\d+)</s;
        $self->{_tic} = 0 unless defined $self->{_tic};
        }
    else {
        my( $entry ) = $contents =~ qr{(<td class="current".*?\d+</td>)}s;
        
        ( $self->{_shortDescr}, undef, $self->{_longDescr}, $self->{_tic} ) = 
            #                  $1         $2    $3             $4
            $entry =~ qr{<a.*>(.*)</a>.*?(<div>(.*)</div>.*?)?(\d+)<}s;

        # it's possible for Yandex to find site under a different address! 
        #    for example, "narod.ru" becomes "narod.yandex.ru"
        # TODO: catch URI as yandex sees it; return as last item in the array

        # main catalog
        ( $entry ) = $contents =~ qr{<div class="path2root">(.*?)</div>}s;
        if( $entry ) {
            $entry =~ s{</?a.*?>|</?h1>|\n}{}gs; # remove A, H1 tags and newline
            $entry =~ s{\x{041A}\x{0430}\x{0442}\x{0430}\x{043B}\x{043E}\x{0433} / }{};
                # removed "Каталог" - we know it's in the catalog
            push( @{$self->{_categories}}, $entry ) if $entry;
        }

        # additional catalogs
        ( $entry ) = $contents =~ qr{<dl class="cat-links">.*?(<a.*?>.*</a>).*?</dd></dl>}s;
        if( $entry ) {
            while( $entry =~ s{<a.*?>(.*?)</a>.*?(<a|$)}{$2}s ) {
                my $path = $1;
                $path =~ s{\x{041A}\x{0430}\x{0442}\x{0430}\x{043B}\x{043E}\x{0433} / }{};
                    # removed "Каталог" - we know it's in the catalog
                push( @{$self->{_categories}}, $path ) if $path;
            }
        }
    }

    return [ $self->{_tic}, $self->{_shortDescr}, $self->{_longDescr}, $self->{_categories} ];
}


# == Convenience functions =================================

sub is_in_catalog {
    my $self = shift;
    return scalar @{$self->{_categories}} > 0 ? 1 : 0;
}

sub tic {
    my $self = shift;
    return $self->{_tic};
}

sub short_description {
    my $self = shift;
    return $self->{_shortDescr};
}

sub long_description {
    my $self = shift;
    return $self->{_longDescr};
}

sub categories {
    my $self = shift;
    return $self->{_categories};
}

1;

__END__

=encoding utf8

=head1 NAME

WWW::Yandex::Catalog::LookupSite - Query Yandex Catalog for a website's presence, it's Index of Citing, descriptions in the catalog, and the list of categories it belongs to.

=head1 SYNOPSIS

    use WWW::Yandex::Catalog::LookupSite;

    my $site = WWW::Yandex::Catalog::LookupSite->new();

    $site->yaca_lookup('www.slovnik.org');

    print $site->tic . "\n";
    print $site->short_description . "\n";
    print $site->long_description . "\n";
    print "$_\n" foreach @{$site->categories};


=head1 DESCRIPTION

The C<WWW::Yandex::Catalog::LookupSite> module retrieves website's Thematic Index of Citing, and checks website's presence in Yandex Catalog, retrieves it's descriptions as recorded in the catalog, and the list of categories it belongs to.

This module uses C<LWP::Simple> for making requests to Yandex Catalog.

=head2 Data retrieved

I<Thematic Index of Citing (tIC)> is technology of Yandex similar to Google's Page Rank. The tIC value's step is 10, so when tIC is under 10, this module will return 0.

Each website in the Yandex Catalog has I<short description>.

I<Not> every website in the Yandex Catalog has I<long description>.

Every website in the Yandex Catalog will belong to at least one I<category>. It may belong to several other categories as well.


=head1 CONSTRUCTOR

=head2 WWW::Yandex::Catalog::LookupSite->new()

Creates and returns a new C<WWW::Yandex::Catalog::LookupSite> object.

    my $site = WWW::Yandex::Catalog::LookupSite->new();


=head1 DATA-FETCHING METHODS

=head2 $site-E<gt>yaca_lookup( $uri )

Given a URL/URI, strips unnessesary data from it (scheme, authentication, port, and query), fetches Yandex Catalog with it, and parses results for data.

Returns an array ref to: C<[ tIC, short description, long description, [catalogs] ]>.
Returns C<undef> if couldn't fetch the URI.

Short and long description are returned as provided by Yandex, in UTF8 encoding.

Catalogs is an array of strings in format similar to "C<Auto & Moto / Motorcycles / Yamaha>". The leading "C<Catalog / >" is striped, I don't believe there're any sites in root of the catalog.

=over 1

=item B<tIC>

C<undef> - if there was an error getting or parsing data.
C<0> - (a) when site is not present in catalog and tIC is < 10. (b) when site is present in catalog, but the catalog reports it as zero (payed submission).
Numeric string when tIC is 10 or greater.

=item B<Short Description>

Returned only when site is present in catalog (in UTF8 encoding); C<undef> otherwise.

=item B<Long Description>

Can be C<undef> when site is present in catalog -- not all sites in the catalog have long description. Returned in UTF8 encoding.

=item B<Categories>

Empty list is returned when site is not present in catalog. At least one entry when present in catalog.

=back


=head1 CONVENIENCE METHODS

These methods can be called only after C<$site-E<gt>yaca_lookup( $uri )>

=head2 $site-E<gt>is_in_catalog

Returns C<1> if any categories has been retrieved; C<0> otherwise.

=head2 $site-E<gt>tic

=for comment
Self explanatory. This comment is here to shut the podchecker up.

=head2 $site-E<gt>short_description

=for comment
Self explanatory. This comment is here to shut the podchecker up.

=head2 $site-E<gt>long_description

=for comment
Self explanatory. This comment is here to shut the podchecker up.

=head2 $site-E<gt>categories

    print $site->tic . "\n";
    if( $site->is_in_catalog ) {
        print $site->short_description . "\n";
        print $site->long_description . "\n";
        print "$_\n" foreach @{$site->categories};
    }


=head1 AUTHOR

Irakliy Sunguryan, C<< <webmaster at slovnik.org> >>, L<http://www.slovnik.org/>


=head1 BUGS

Please report any to C<bug-www-yandex-catalog-lookupsite at rt.cpan.org>, or through 
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Yandex-Catalog-LookupSite>.


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Irakliy Sunguryan.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

=cut
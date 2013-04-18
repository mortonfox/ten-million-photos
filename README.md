# ten-million-photos

## Purpose

Scripts for generating 10 Million Photos Flickr group stats


## Installation

Rename `apikey.conf-template` to `apikey.conf`. Fill in your Flickr API key,
authentication token, and shared secret.

A Flickr API key with read permission is sufficient.


## Invocation

`perl runten2.pl`

Update database with new photo stats since the last run of `runten2.pl`. Also
use this script if starting from scratch with no database or an empty
database. It will create a new database if necessary.

`perl tenshort.pl`

Generate stats for top 150 posters. Rank table will be written to `newcount.txt`.

`perl toppostr.pl`

Generate rank tables for top 25 posters in the past day and past week. Tables will be written to `newtop.txt`.


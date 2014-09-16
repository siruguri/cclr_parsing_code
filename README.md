# Introduction

This application parses a MySQL database dump of contacts from a Civi database and converts it to a format suitable for
import via the Google Shared Contacts API.

# Installation

1. This code has been tested on Ruby 2.1.2 (MRI)
1. This code requires the following gems to be installed prior to running:
   * [XML Simple](https://github.com/maik/xml-simple/): `gem install xml-simple`
   * [ParseConfig](https://github.com/datafolklabs/ruby-parseconfig/): `gem install parse-config`
1. Download the [Google Shared Contacts API](https://github.com/siruguri/google_api_client/) gem to a folder

        git clone https://github.com/siruguri/google_api_client

Note that these have already been installed on the CCLR machine at `216.70.92.135`. Login as `cclr` via SSH and change to the `code` folder in the home folder to run the commands in the following section.

    ssh cclr@216.70.92.135 # Enter password when prompted
    /home/cclr$ > cd code

# Instructions for Use

These instructions assume familiarity with using a UNIX command line interface, or shell. Any lines in this form refer to a command typed in at the shell:

    ~cclr.org$ > ls

## Dump MySQL databse

The MySQL database dump can be obtained by running the script `connect_to_db.sh` in the `scripts` folder. This dump
script assumes that there is a file named `queries.txt` in the folder it is run in. It outputs the table information to
STDOUT:

    ~cclr.org/code/parsing_code$ > cd /scripts
    ~cclr.org/code/parsing_code$ > connect_to_db.sh > tables.txt

## Run the parsing code

Note that the parsing code assumes that the folder containing the Google Shared Contacts API Ruby gem is a peer of the
folder containing the parsing code. This is how it has already been set up on the CCLR account.

The parsing code can perform three actions: **list**, **delete**, and **update**

    # This will output an XML dump of all the existing contacts.
    ~cclr.org/code/parsing_code$ > ruby parse_civi.rb tables.txt list

To update the contacts with the latest Civi database dump, you have to delete existing contacts and then run an update. Please wait for 5-10 seconds between the two steps.

    # This will delete all existing contacts in the directory
    ~cclr.org/code/parsing_code$ > ruby parse_civi.rb tables.txt delete

    # This will update contacts from the tables.txt file
    ~cclr.org/code/parsing_code$ > ruby parse_civi.rb tables.txt update

## Configuration Options

All the configuration options are in a file called `cclr_config.ini` These are as follows - they need not be changed
except for the password if it's updated, and for the `max-results` parameter in the `endpoint` URL, if there are more
than 5000 contacts in the directory:

    client_login_email='cclrdev@cclr.org'
    client_login_pwd='the password for the account'
    client_login_service_name='cp'
    client_login_account_type='HOSTED'
    endpoint='/m8/feeds/contacts/cclr.org/full?max-results=5000'
    source='CCLR_dev_test'
    batch_endpoint='/m8/feeds/contacts/cclr.org/full/batch'
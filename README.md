# crtinfo
Certificate Transparency infodigger

## Usage
	./crtinfo.sh -d <domain.tld>

## Okay but what is this?

This tool is a simple, stupid information digger for certificates, more precisely Certificate Transparency.
By querying [crt.sh](https://crt.sh) you can find several certificates and subdomains for a domain.
The working mechanism is the following:
  * send a query for %.domain.tld, and download all certificates
  * process these certificates and extract subdomains
    * from the subject field
    * from the SAN
  * try to DNSresolve all these domains

Thats all so far...


## TODO
- colors
- show expired certs
- email extract
- output: xml,json,csv,html,whatever



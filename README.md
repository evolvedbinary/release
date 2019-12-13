# Release

A collection of utilities for preparing releases:

- Quarterly Release Helper: generates draft press release and tweets for “quarterly releases” of the _FRUS_ Digital archive
- Ebook Batch Helper: generates epubs and mobi-bound epubs of _FRUS_ volumes from TEI XML
- S3 Cache Helper: polls S3 for presence of PDFs and ebooks and their sizes - so links to these resources appear

## Dependencies

- Assumes [HistoryAtState/hsg-project](https://github.com/HistoryAtState/hsg-project) is installed

## Build

1. Single `xar` file: The `collection.xconf` will only contain the index, not any triggers!
    ~~~shell
    ant
    ~~~

2. DEV environment: The replication triggers for the producer server are enabled in  `collection.xconf` and point to the dev server's replication service IP.
    ~~~shell
    ant xar-dev
    ~~~

3. PROD environment: Same as in 2. but for PROD destination
    ~~~shell
    ant xar-prod
    ~~~

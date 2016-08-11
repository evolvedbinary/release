xquery version "1.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: the target collection into which the app is deployed :)
declare variable $target external;

xdb:create-collection($target, 'epub-cache')